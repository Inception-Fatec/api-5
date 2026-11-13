// #TG-90: envio de pontos externos por CSV (RF-07, US #11) pelo modal único
// da tela de ETL, que aceita .zip (BDGD) ou .csv e segue o fluxo certo pela
// extensão. Prévia lida no front, resumo devolvido pelo POST
// /etl/upload-csv (#TG-89), mensagens de erro e aba de ETL só para ADM.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tecsys_app/app/navigation/nav_items.dart';
import 'package:tecsys_app/features/etl_geodados/etl_geodados_screen.dart';
import 'package:tecsys_app/features/etl_geodados/models/csv_import_resumo.dart';
import 'package:tecsys_app/features/etl_geodados/services/csv_preview.dart';
import 'package:tecsys_app/features/etl_geodados/services/etl_service.dart';
import 'package:tecsys_app/features/etl_geodados/upload_modal_dialog.dart';
import 'package:tecsys_app/features/etl_geodados/widgets/etl_modal.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

/// Distribuidoras/municípios fixos, sem chamar o backend.
class _DistribuidorasFalsas extends DistribuidorasService {
  _DistribuidorasFalsas(this.lista, this.municipios);

  final List<Distribuidora> lista;
  final List<int> municipios;

  @override
  Future<List<Distribuidora>> listar() async => lista;

  @override
  Future<List<int>> codigosMunicipios(String distCode) async => municipios;
}

void main() {
  group('prévia do CSV (analisarCsv)', () {
    test('cabeçalho em qualquer ordem e maiúsculas: nada faltando', () {
      final p = analisarCsv('PAPEL;Longitude;id;LATITUDE;descricao\n'
          'candidato;-45,88;P01;-23,17;Topo\n');
      expect(p.colunasFaltando, isEmpty);
      expect(p.cabecalho, ['PAPEL', 'Longitude', 'id', 'LATITUDE', 'descricao']);
      expect(p.totalLinhas, 1);
      expect(p.podeEnviar, isTrue);
      expect(p.avisos, isEmpty);
    });

    test('separa por ; respeitando aspas e "" de escape', () {
      expect(dividirLinhaCsv('P01;"Rua A; nº 10";"diz ""oi"""'),
          ['P01', 'Rua A; nº 10', 'diz "oi"']);
      final p = analisarCsv(
          'id;latitude;longitude;papel;descricao\r\nP01;-23.1;-45.8;interesse;"a;b"\r\n');
      expect(p.linhas.single.celulas, ['P01', '-23.1', '-45.8', 'interesse', 'a;b']);
      expect(p.linhaDesalinhada(p.linhas.single), isFalse);
    });

    test('colunas obrigatórias faltando bloqueiam o envio com aviso', () {
      final p = analisarCsv('id;latitude;descricao\nP01;-23;x\n');
      expect(p.colunasFaltando, ['longitude', 'papel']);
      expect(p.podeEnviar, isFalse);
      expect(p.avisos.single, contains('longitude, papel'));
    });

    test('detecta vírgula como separador', () {
      final p = analisarCsv('id,latitude,longitude,papel\nP01,-23,-45,candidato\n');
      expect(p.pareceSeparadorVirgula, isTrue);
      expect(p.colunasFaltando, kColunasObrigatoriasCsv);
      expect(p.avisos.first, contains('vírgula'));
    });

    test('BOM UTF-8 no começo é ignorado', () {
      final p = analisarCsv(decodificarCsv(Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ...utf8.encode('id;latitude;longitude;papel\nP1;1;2;candidato\n')])));
      expect(p.cabecalho.first, 'id');
      expect(p.colunasFaltando, isEmpty);
    });

    test('Latin-1 (Excel em português) quando não é UTF-8 válido', () {
      final bytes = Uint8List.fromList(
          latin1.encode('id;latitude;longitude;papel;descricao\nP1;1;2;interesse;Praça São João\n'));
      expect(analisarCsv(decodificarCsv(bytes)).linhas.single.celulas.last, 'Praça São João');
    });

    test('mostra só as 5 primeiras linhas, conta todas e numera como o backend', () {
      final b = StringBuffer('id;latitude;longitude;papel\n');
      for (int i = 1; i <= 10; i++) {
        b.write('P$i;-23;-45;candidato\n');
        if (i == 2) b.write('\n'); // linha em branco: ignorada, mas conta no número
      }
      final p = analisarCsv(b.toString());
      expect(p.totalLinhas, 10);
      expect(p.linhas.length, 5);
      expect(p.linhas.map((l) => l.numero), [2, 3, 5, 6, 7]);
    });

    test('linha com número de colunas diferente é marcada', () {
      final p = analisarCsv('id;latitude;longitude;papel\nP1;-23;-45\n');
      expect(p.linhaDesalinhada(p.linhas.single), isTrue);
    });

    test('só cabeçalho: sem linhas de dados, não envia', () {
      final p = analisarCsv('id;latitude;longitude;papel\n\n');
      expect(p.totalLinhas, 0);
      expect(p.podeEnviar, isFalse);
      expect(p.avisos.single, contains('não há linhas de dados'));
    });
  });

  group('validação do arquivo antes de enviar (caso de teste 1)', () {
    test('arquivo que não é CSV → mensagem clara', () {
      final msg = validarArquivoCsv('pontos.xlsx', _utf8('qualquer coisa'));
      expect(msg, contains('não é um CSV'));
      expect(msg, contains('.csv'));
    });

    test('arquivo vazio → mensagem', () {
      expect(validarArquivoCsv('pontos.csv', Uint8List(0)), contains('está vazio'));
      expect(validarArquivoCsv('pontos.csv', _utf8('\n  \n')), contains('está vazio'));
    });

    test('CSV com conteúdo (extensão em maiúsculas) passa', () {
      expect(validarArquivoCsv('PONTOS.CSV', _utf8('id;latitude;longitude;papel\n')), isNull);
    });
  });

  group('modelo para baixar', () {
    test('usa ; e traz uma linha por papel, com BOM', () {
      final bytes = bytesModeloCsv();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final p = analisarCsv(decodificarCsv(bytes));
      expect(p.cabecalho, ['id', 'latitude', 'longitude', 'papel', 'descricao']);
      expect(p.podeEnviar, isTrue);
      expect(p.linhas.map((l) => l.celulas[3]), kPapeisCsv);
    });
  });

  group('CsvImportResumo.fromJson', () {
    test('CT01: 10 linhas, 2 com latitude inválida → 8 importadas, 2 rejeitadas', () {
      final r = CsvImportResumo.fromJson({
        'total': 10,
        'importadas': 8,
        'jaExistentes': 0,
        'rejeitadas': 2,
        'rejeicoes': [
          {'linha': 4, 'id': 'P03', 'motivo': 'latitude fora da faixa (-90 a 90): 123'},
          {'linha': 9, 'id': 'P08', 'motivo': 'latitude não numérica: abc'},
        ],
      });
      expect(r.importadas, 8);
      expect(r.rejeitadas, 2);
      expect(r.rejeicoes.first.linha, 4);
      expect(r.rejeicoes.first.id, 'P03');
      expect(r.rejeicoes.first.motivo, contains('fora da faixa'));
      expect(r.texto, '8 importadas · 0 já existentes · 2 rejeitadas (de 10 linhas)');
      expect(r.soJaExistentes, isFalse);
    });

    test('rejeicoes vazia e mesmo CSV duas vezes (só já existentes)', () {
      final r = CsvImportResumo.fromJson({
        'total': 10,
        'importadas': 0,
        'jaExistentes': 10,
        'rejeitadas': 0,
        'rejeicoes': [],
      });
      expect(r.rejeicoes, isEmpty);
      expect(r.soJaExistentes, isTrue);
    });

    test('campos ausentes não quebram; rejeitadas cai no tamanho da lista', () {
      final r = CsvImportResumo.fromJson({
        'rejeicoes': [
          {'linha': '3', 'motivo': 'id vazio'},
        ],
      });
      expect(r.total, 0);
      expect(r.rejeitadas, 1);
      expect(r.rejeicoes.single.linha, 3);
      expect(r.rejeicoes.single.id, '');
    });

    test('rejeições viram CSV com aspas quando o motivo tem ;', () {
      final r = CsvImportResumo.fromJson({
        'rejeicoes': [
          {'linha': 4, 'id': 'P03', 'motivo': 'id vazio; latitude vazia'},
        ],
      });
      expect(r.rejeicoesCsv(), 'linha;id;motivo\r\n4;P03;"id vazio; latitude vazia"\r\n');
    });
  });

  group('EtlService.enviarCsv', () {
    http.StreamedResponse resposta(int status, Object corpo) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(corpo))), status,
        headers: {'content-type': 'application/json'});

    test('manda o arquivo e os campos distribuidora e município', () async {
      late http.MultipartRequest enviada;
      final client = MockClient.streaming((req, _) async {
        enviada = req as http.MultipartRequest;
        return resposta(200, {
          'total': 1, 'importadas': 1, 'jaExistentes': 0, 'rejeitadas': 0, 'rejeicoes': [],
        });
      });
      final r = await EtlService.enviarCsv(
        bytes: _utf8('id;latitude;longitude;papel\nP1;-23;-45;candidato\n'),
        nomeArquivo: 'pontos.csv',
        distribuidora: '391',
        municipio: '3549904',
        onProgress: (_) {},
        client: client,
      );
      expect(r.importadas, 1);
      expect(enviada.url.path, endsWith('/etl/upload-csv'));
      expect(enviada.fields, {'distribuidora': '391', 'municipio': '3549904'});
      expect(enviada.files.single.field, 'file');
      expect(enviada.files.single.filename, 'pontos.csv');
    });

    test('403 → apenas administradores', () {
      expect(
        () => EtlService.resumoCsvDaResposta(403, {'message': 'Access Denied'}),
        throwsA(isA<EtlUploadException>().having(
            (e) => e.mensagem, 'mensagem', 'Apenas administradores podem importar pontos.')),
      );
    });

    test('422 → mostra o message do backend', () {
      const msg = "Cabeçalho inválido: faltam as colunas [papel]. O separador deve ser ';'.";
      expect(
        () => EtlService.resumoCsvDaResposta(422, {'status': 422, 'message': msg}),
        throwsA(isA<EtlUploadException>().having((e) => e.mensagem, 'mensagem', msg)),
      );
    });

    test('falha de rede → mensagem de conexão', () async {
      final client = MockClient((_) async => throw http.ClientException('sem rede'));
      await expectLater(
        EtlService.enviarCsv(
          bytes: _utf8('x'),
          nomeArquivo: 'p.csv',
          distribuidora: '391',
          municipio: '3549904',
          onProgress: (_) {},
          client: client,
        ),
        throwsA(isA<EtlUploadException>()
            .having((e) => e.mensagem, 'mensagem', contains('Falha na conexão'))),
      );
    });
  });

  group('tipo do arquivo pela extensão', () {
    test('.zip e .csv (sem diferenciar maiúsculas); o resto não', () {
      expect(tipoDoArquivo('EDP_SP.gdb.zip'), TipoArquivoEnvio.zip);
      expect(tipoDoArquivo('PONTOS.CSV'), TipoArquivoEnvio.csv);
      expect(tipoDoArquivo('pontos.txt'), isNull);
      expect(tipoDoArquivo('pontos.xlsx'), isNull);
    });
  });

  group('tela de ETL: um botão só (caso de teste 3)', () {
    test('usuário comum não vê a aba de ETL (e com ela o envio de CSV)', () {
      expect(NavItems.forRole('USER'), isNot(contains(NavItems.etlGeodados)));
      expect(NavItems.forRole(null), isNot(contains(NavItems.etlGeodados)));
      expect(NavItems.forRole('ADM'), contains(NavItems.etlGeodados));
    });

    Future<void> montar(WidgetTester tester, {required bool mobile, VoidCallback? onUpload}) {
      tester.view.physicalSize = Size(mobile ? 400 : 1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EtlPageHeader(mobile: mobile, onUpload: onUpload ?? () {}),
          ),
        ),
      ));
    }

    testWidgets('"Enviar arquivo" abre o modal; não há botão separado de CSV', (tester) async {
      int cliques = 0;
      await montar(tester, mobile: false, onUpload: () => cliques++);
      await tester.tap(find.text('Enviar arquivo'));
      expect(cliques, 1);
      expect(find.text('Importar pontos (CSV)'), findsNothing);
      expect(find.text('Novo upload (.zip)'), findsNothing);

      await montar(tester, mobile: true);
      expect(find.text('Enviar arquivo'), findsOneWidget);
    });
  });

  group('modal único "Enviar arquivo"', () {
    late Directory pasta;
    setUp(() => pasta = Directory.systemTemp.createTempSync('tg90_'));
    tearDown(() => pasta.deleteSync(recursive: true));

    Future<void> abrir(WidgetTester tester,
        {List<Distribuidora> distribuidoras = const [Distribuidora(codigo: '391', nome: 'EDP SP')],
        List<int> municipios = const [3549904]}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UploadModalDialog(
            distribuidorasService: _DistribuidorasFalsas(distribuidoras, municipios),
          ),
        ),
      ));
    }

    /// Solta o arquivo na área de arrastar, como no desktop (pelo caminho).
    Future<void> soltar(WidgetTester tester, String nome, List<int> bytes) async {
      final File arquivo = File('${pasta.path}${Platform.pathSeparator}$nome')
        ..writeAsBytesSync(bytes);
      final EtlDropZone zona = tester.widget<EtlDropZone>(find.byType(EtlDropZone));
      // Leitura do disco de verdade: fora do relógio falso do teste.
      await tester.runAsync(() async {
        zona.onDrop(DropItemFile(arquivo.path));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('abre com o título "Enviar arquivo", diretrizes e modelo CSV', (tester) async {
      await abrir(tester);
      expect(find.text('Enviar arquivo'), findsOneWidget);
      expect(find.text('Baixar modelo CSV'), findsOneWidget);
      expect(find.textContaining('.zip ou .csv'), findsOneWidget);
    });

    testWidgets('.zip vai para o fluxo da BDGD', (tester) async {
      await abrir(tester);
      await soltar(tester, 'EDP_SP.zip',
          [0x50, 0x4B, 0x03, 0x04, ...ascii.encode('EDP_SP.gdb/a00000000000000000000000000')]);
      expect(find.text('Geodatabase (.zip)'), findsOneWidget);
      expect(find.text('Pronto para processamento'), findsOneWidget);
      expect(find.text('Enviar e analisar'), findsOneWidget);
      expect(find.text('Pontos externos (CSV)'), findsNothing);
    });

    testWidgets('.csv vai para o fluxo de pontos, com o arquivo já escolhido', (tester) async {
      await abrir(tester);
      await soltar(tester, 'pontos.csv',
          utf8.encode('id;latitude;longitude;papel\nP1;-23,1;-45,8;candidato\n'));
      expect(find.text('Pontos externos (CSV)'), findsOneWidget);
      expect(find.text('pontos.csv'), findsOneWidget);
      expect(find.byType(EtlDropZone), findsNothing);
      // Distribuidora e município únicos já vêm escolhidos.
      expect(find.textContaining('(391)'), findsOneWidget);
      expect(find.textContaining('3549904'), findsOneWidget);
      expect(find.text('Prévia do arquivo'), findsOneWidget);
      expect(find.text('Importar pontos'), findsOneWidget);

      // "Trocar arquivo" volta para a área que aceita os dois tipos.
      await tester.tap(find.byIcon(Icons.sync));
      await tester.pumpAndSettle();
      expect(find.text('Enviar arquivo'), findsOneWidget);
      expect(find.byType(EtlDropZone), findsOneWidget);
    });

    testWidgets('.txt mostra a mensagem de formato', (tester) async {
      await abrir(tester);
      await soltar(tester, 'pontos.txt', utf8.encode('id;latitude;longitude;papel\n'));
      expect(find.text(kMensagemFormatoInvalido), findsOneWidget);
      expect(find.text('Enviar arquivo'), findsOneWidget);
      expect(find.text('Pontos externos (CSV)'), findsNothing);
    });

    testWidgets('.csv vazio mostra mensagem e não troca o fluxo', (tester) async {
      await abrir(tester);
      await soltar(tester, 'vazio.csv', const <int>[]);
      expect(find.textContaining('está vazio'), findsOneWidget);
      expect(find.text('Pontos externos (CSV)'), findsNothing);
    });

    testWidgets('.csv sem distribuidora no banco pede o .zip antes', (tester) async {
      await abrir(tester, distribuidoras: const [], municipios: const []);
      await soltar(tester, 'pontos.csv',
          utf8.encode('id;latitude;longitude;papel\nP1;-23;-45;candidato\n'));
      expect(find.textContaining('Nenhuma distribuidora com dados'), findsOneWidget);
    });
  });
}
