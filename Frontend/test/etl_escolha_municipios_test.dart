// #TG-143: upload em dois passos. A carga volta do backend "aguardando
// escolha" com os municípios da .gdb, e a tela só deixa escolher entre eles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/etl_geodados/models/etl_carga.dart';
import 'package:tecsys_app/features/etl_geodados/widgets/escolha_municipios.dart';

Map<String, dynamic> cargaAguardando() => {
      'id': 12,
      'status': 'AWAITING_SELECTION',
      'originalFilename': 'EDP_ES.gdb.zip',
      'municipios': <String>[],
      'inspecao': {
        'distribuidora': '380',
        'periodo': {'inicio': '01/01/2025', 'fim': '31/12/2025'},
        'municipios': [
          {'codigo': '3203205', 'transformadores': 7543, 'consumidores_bt': 54000},
          {'codigo': '3201209', 'transformadores': 4717, 'consumidores_bt': 81000},
        ],
      },
    };

void main() {
  group('status e inspeção vindos do backend', () {
    test('carga aguardando escolha traz distribuidora, período e municípios', () {
      final carga = EtlCarga.fromJson(cargaAguardando());
      expect(carga.status, EtlCargaStatus.aguardandoEscolha);
      expect(carga.statusLabel, 'Aguardando escolha');
      expect(carga.municipios, isEmpty);
      final insp = carga.inspecao!;
      expect(insp.distribuidora, '380');
      expect(insp.periodoInicio, '01/01/2025');
      expect(insp.municipios.map((m) => m.codigo), ['3203205', '3201209']);
      expect(insp.municipios.first.transformadores, 7543);
    });

    test('INSPECTING conta como processando e CANCELED como cancelado', () {
      expect(EtlCarga.fromJson({'id': 1, 'status': 'INSPECTING'}).status, EtlCargaStatus.processando);
      expect(EtlCarga.fromJson({'id': 2, 'status': 'CANCELED'}).status, EtlCargaStatus.cancelado);
    });

    test('lê a etapa atual da carga em andamento', () {
      final carga = EtlCarga.fromJson({'id': 3, 'status': 'RUNNING', 'stage': 'Gravando a rede no banco'});
      expect(carga.etapa, 'Gravando a rede no banco');
      expect(carga.inspecao, isNull);
    });
  });

  test('baixa tensão da .gdb: registros por ponto e consumidores gravados (#TG-144)', () {
    final carga = EtlCarga.fromJson({
      'id': 4,
      'status': 'SUCCESS',
      'summary': {
        'geodatabase': {
          'tabelas': {
            'ucbt': {
              'consumidores_ativos': 166534,
              'registros': 37973,
              'inseridos': 37948,
              'consumidores_gravados': 166430,
              'sem_transformador': 25,
            },
          },
        },
      },
    });
    final bt = carga.camadas.singleWhere((c) => c.nome == 'ucbt');
    expect(bt.naCidade, 37973);
    expect(bt.gravados, 37948);
    expect(bt.ignorados, 25);
    expect(bt.consumidores, 166430);
  });

  testWidgets('só lista os municípios do arquivo e "Selecionar todos" marca os dois', (tester) async {
    Set<String> escolhidos = <String>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EscolhaMunicipios(
            inspecao: EtlCarga.fromJson(cargaAguardando()).inspecao!,
            onChanged: (s) => escolhidos = s,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Distribuidora 380'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('7.543 transformadores · 54.000 consumidores BT'), findsOneWidget);

    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();
    expect(escolhidos, {'3203205', '3201209'});
    expect(find.text('2 selecionado(s)'), findsOneWidget);
  });
}
