// #TG-90: importações de CSV no mesmo histórico das cargas da BDGD. O
// backend grava cada importação em etl_jobs com summary.tipo = "csv"; a tela
// lista tudo junto, com o filtro Todos | ETL | CSV.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tecsys_app/features/etl_geodados/carga_detalhes_dialog.dart';
import 'package:tecsys_app/features/etl_geodados/etl_geodados_screen.dart';
import 'package:tecsys_app/features/etl_geodados/models/etl_carga.dart';
import 'package:tecsys_app/features/etl_geodados/models/ponto_importado.dart';
import 'package:tecsys_app/features/etl_geodados/services/etl_service.dart';

/// Como o GET /etl/jobs devolve uma importação de CSV concluída.
Map<String, dynamic> jobCsv() => {
      'id': 41,
      'status': 'SUCCESS',
      'originalFilename': 'pontos.csv',
      'fileSizeBytes': 350,
      'municipios': ['3549904'],
      'summary': {
        'tipo': 'csv',
        'distribuidora': '391',
        'municipio': '3549904',
        'total': 10,
        'importadas': 8,
        'jaExistentes': 0,
        'rejeitadas': 2,
        'rejeicoes': [
          {'linha': 2, 'id': 'P1', 'motivo': 'latitude fora da faixa (-90 a 90): 120'},
          {'linha': 3, 'id': 'P2', 'motivo': 'latitude fora da faixa (-90 a 90): 120'},
        ],
      },
      'createdAt': '2026-11-13T15:00:00Z',
      'startedAt': '2026-11-13T15:00:00Z',
      'finishedAt': '2026-11-13T15:00:01Z',
    };

/// Importação que falhou antes de ler as linhas (cabeçalho inválido).
Map<String, dynamic> jobCsvFalhou() => {
      'id': 42,
      'status': 'FAILED',
      'originalFilename': 'virgula.csv',
      'municipios': ['3549904'],
      'summary': {'tipo': 'csv', 'distribuidora': '391', 'municipio': '3549904'},
      'errorMessage': "Cabeçalho inválido: faltam as colunas [papel]. O separador deve ser ';'.",
    };

Map<String, dynamic> jobEtl() => {
      'id': 40,
      'status': 'SUCCESS',
      'originalFilename': 'EDP_SP.gdb.zip',
      'municipios': ['3549904'],
      'summary': {
        'geodatabase': {
          'tabelas': {
            'ssdmt': {'lidos': 10, 'inseridos': 10},
          },
        },
      },
    };

void main() {
  group('EtlCarga com importação de CSV', () {
    test('summary.tipo = csv vira item de CSV com o resumo da importação', () {
      final c = EtlCarga.fromJson(jobCsv());
      expect(c.ehCsv, isTrue);
      expect(c.status, EtlCargaStatus.concluido);
      expect(c.distribuidora, '391');
      expect(c.municipios, ['3549904']);
      expect(c.csv!.importadas, 8);
      expect(c.csv!.rejeicoes.first.motivo, contains('fora da faixa'));
      expect(c.resumo, contains('8 importadas · 0 já existentes · 2 rejeitadas (de 10 linhas)'));
      expect(c.totalCamadas, 0);
    });

    test('importação que falhou: item de CSV com erro e sem resumo', () {
      final c = EtlCarga.fromJson(jobCsvFalhou());
      expect(c.ehCsv, isTrue);
      expect(c.status, EtlCargaStatus.erro);
      expect(c.csv, isNull);
      expect(c.errorMessage, startsWith('Cabeçalho inválido'));
    });

    test('carga do .zip continua como antes', () {
      final c = EtlCarga.fromJson(jobEtl());
      expect(c.ehCsv, isFalse);
      expect(c.tipo, EtlCargaTipo.etl);
      expect(c.csv, isNull);
      expect(c.totalCamadas, 1);
    });

    test('rejeições omitidas no histórico', () {
      final json = jobCsv();
      (json['summary'] as Map)['rejeicoesOmitidas'] = 20;
      expect(EtlCarga.fromJson(json).csv!.rejeicoesOmitidas, 20);
    });
  });

  group('filtro do histórico', () {
    final cargas = EtlCarga.listFromJson([jobCsv(), jobEtl(), jobCsvFalhou()]);

    test('Todos | ETL | CSV', () {
      expect(filtrarHistorico(cargas, FiltroHistorico.todos).length, 3);
      expect(filtrarHistorico(cargas, FiltroHistorico.etl).map((c) => c.nomeArquivo), ['EDP_SP.gdb.zip']);
      expect(filtrarHistorico(cargas, FiltroHistorico.csv).map((c) => c.nomeArquivo),
          ['pontos.csv', 'virgula.csv']);
    });
  });

  group('busca no histórico', () {
    final cargas = EtlCarga.listFromJson([jobCsv(), jobEtl(), jobCsvFalhou()]);

    test('por arquivo e por distribuidora, sem diferenciar maiúsculas', () {
      expect(buscarNoHistorico(cargas, '').length, 3);
      expect(buscarNoHistorico(cargas, 'EDP_SP').map((c) => c.nomeArquivo), ['EDP_SP.gdb.zip']);
      expect(buscarNoHistorico(cargas, 'virgula').single.nomeArquivo, 'virgula.csv');
      // origemCsv traz "Pontos externos (CSV) · ... (391)"
      expect(buscarNoHistorico(cargas, '(391)').length, 2);
    });

    testWidgets('chips com a contagem de cada tipo, no padrão de Projetos', (tester) async {
      FiltroHistorico? escolhido;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FiltroHistoricoChips(
            cargas: cargas,
            filtro: FiltroHistorico.todos,
            onFiltro: (f) => escolhido = f,
          ),
        ),
      ));
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('ETL (1)'), findsOneWidget);
      await tester.tap(find.text('CSV (2)'));
      expect(escolhido, FiltroHistorico.csv);
    });
  });

  group('detalhes do item', () {
    Map<String, dynamic> pontosJson() => {
          'total': 3,
          'limite': 1000,
          'pontos': [
            {'id': 'P3', 'papel': 'candidato', 'descricao': 'Topo', 'latitude': -23.1, 'longitude': -45.8},
            {'id': 'P4', 'papel': 'candidato', 'descricao': null, 'latitude': -23.2, 'longitude': -45.9},
            {'id': 'P5', 'papel': 'interesse', 'descricao': 'Escola', 'latitude': -23.3, 'longitude': -45.7},
          ],
        };

    Future<void> abrir(WidgetTester tester, EtlCarga carga,
        {CarregarPontosDaImportacao? carregar}) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CargaDetalhesDialog(
            carga: carga,
            carregarPontos: carregar ?? (_) async => PontosDaImportacao.fromJson(pontosJson()),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('CSV mostra as linhas importadas e filtra por papel', (tester) async {
      String? pedido;
      await abrir(tester, EtlCarga.fromJson(jobCsv()), carregar: (id) async {
        pedido = id;
        return PontosDaImportacao.fromJson(pontosJson());
      });
      expect(pedido, '41');
      expect(find.text('Linhas importadas (3)'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('Escola'), findsOneWidget);
      expect(find.text('Todos (3)'), findsOneWidget);

      // A linha de chips rola na horizontal; a fonte de teste é bem larga.
      await tester.ensureVisible(find.text('Ponto de interesse (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ponto de interesse (1)'));
      await tester.pumpAndSettle();
      expect(find.text('P3'), findsNothing);
      expect(find.text('P5'), findsOneWidget);
    });

    testWidgets('importação antiga, sem pontos ligados, explica o motivo', (tester) async {
      await abrir(tester, EtlCarga.fromJson(jobCsv()),
          carregar: (_) async => const PontosDaImportacao(total: 0, limite: 1000, pontos: []));
      expect(find.textContaining('não estão ligadas a ela'), findsOneWidget);
    });

    testWidgets('importação sem linha nova não repete o aviso nem busca as linhas', (tester) async {
      final json = jobCsv();
      (json['summary'] as Map)
        ..['importadas'] = 0
        ..['jaExistentes'] = 8;
      bool buscou = false;
      await abrir(tester, EtlCarga.fromJson(json), carregar: (_) async {
        buscou = true;
        return const PontosDaImportacao(total: 0, limite: 1000, pontos: []);
      });
      expect(buscou, isFalse);
      expect(find.textContaining('Linhas importadas'), findsNothing);
      expect(find.textContaining('Nenhum ponto novo'), findsOneWidget);
    });

    testWidgets('erro ao carregar as linhas mostra "Tentar de novo"', (tester) async {
      await abrir(tester, EtlCarga.fromJson(jobCsv()),
          carregar: (_) async => throw const EtlUploadException('Falha na conexão.'));
      expect(find.text('Falha na conexão.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('CSV mostra números da importação e linhas rejeitadas', (tester) async {
      await abrir(tester, EtlCarga.fromJson(jobCsv()));
      expect(find.text('pontos.csv'), findsOneWidget);
      expect(find.textContaining('Pontos externos (CSV)'), findsOneWidget);
      expect(find.text('Linhas no Arquivo'), findsOneWidget);
      expect(find.text('Pontos Importados'), findsOneWidget);
      expect(find.text('Linhas rejeitadas (2)'), findsOneWidget);
      expect(find.text('Linha 2'), findsOneWidget);
      // Sem a tabela de camadas PostGIS do .zip.
      expect(find.text('Tabela PostGIS'), findsNothing);
    });

    testWidgets('CSV que falhou mostra o motivo', (tester) async {
      await abrir(tester, EtlCarga.fromJson(jobCsvFalhou()));
      expect(find.textContaining('Cabeçalho inválido'), findsOneWidget);
    });

    testWidgets('.zip continua com as métricas e a tabela de camadas', (tester) async {
      await abrir(tester, EtlCarga.fromJson(jobEtl()));
      expect(find.text('Tabelas Carregadas'), findsOneWidget);
      expect(find.text('Tabela PostGIS'), findsOneWidget);
      expect(find.text('Linhas no Arquivo'), findsNothing);
      expect(find.textContaining('Linhas importadas'), findsNothing);
    });
  });

  group('pontos de uma importação', () {
    test('GET /etl/jobs/{id}/pontos e leitura da resposta', () async {
      late Uri chamada;
      final client = MockClient((req) async {
        chamada = req.url;
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'total': 1,
              'limite': 1000,
              'pontos': [
                {'id': 'P1', 'papel': 'candidato', 'descricao': 'Prédio', 'latitude': -23.1, 'longitude': -45.8},
              ],
            })),
            200);
      });
      final r = await EtlService.listarPontosDaImportacao('41', client: client);
      expect(chamada.path, endsWith('/etl/jobs/41/pontos'));
      expect(chamada.queryParameters['limite'], '1000');
      expect(r.pontos.single.descricao, 'Prédio');
      expect(r.cortada, isFalse);
    });

    test('erro do backend vira mensagem', () async {
      final client = MockClient((_) async =>
          http.Response.bytes(utf8.encode(jsonEncode({'message': 'Acesso negado'})), 403));
      await expectLater(EtlService.listarPontosDaImportacao('41', client: client),
          throwsA(isA<EtlUploadException>().having((e) => e.mensagem, 'mensagem', 'Acesso negado')));
    });

    test('baixar no mesmo formato do CSV de importação', () {
      final l = PontosDaImportacao.fromJson({
        'total': 2,
        'pontos': [
          {'id': 'P1', 'papel': 'candidato', 'descricao': 'a;b', 'latitude': -23.1, 'longitude': -45.8},
          {'id': 'P2', 'papel': 'interesse', 'latitude': -23.2, 'longitude': -45.9},
        ],
      });
      expect(
          l.comoCsv(),
          'id;latitude;longitude;papel;descricao\r\n'
          'P1;-23.1;-45.8;candidato;"a;b"\r\n'
          'P2;-23.2;-45.9;interesse;\r\n');
    });
  });
}
