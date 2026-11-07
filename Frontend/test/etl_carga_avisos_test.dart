import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tecsys_app/features/etl_geodados/carga_detalhes_dialog.dart';
import 'package:tecsys_app/features/etl_geodados/models/etl_carga.dart';

void main() {
  const aviso = 'Baixa tensão não carregada: rode o preload_ucbt.py.';

  test('lê os avisos de summary.avisos', () {
    final carga = EtlCarga.fromJson({
      'id': 1,
      'status': 'SUCCESS',
      'summary': {
        'avisos': [aviso],
        'geodatabase': {'avisos': [aviso], 'tabelas': {}},
      },
    });
    expect(carga.avisos, [aviso]);
    expect(carga.status, EtlCargaStatus.concluido);
  });

  test('sem summary.avisos, junta os avisos de cada bloco', () {
    final carga = EtlCarga.fromJson({
      'id': 2,
      'status': 'SUCCESS',
      'summary': {
        'geodatabase': {'avisos': [aviso]},
        'consumidores': {'tabelas': {}},
      },
    });
    expect(carga.avisos, [aviso]);
  });

  test('carga sem avisos ou sem summary devolve lista vazia', () {
    expect(EtlCarga.fromJson({'id': 3, 'status': 'SUCCESS', 'summary': {'avisos': []}}).avisos, isEmpty);
    expect(EtlCarga.fromJson({'id': 4, 'status': 'RUNNING'}).avisos, isEmpty);
  });

  testWidgets('modal de detalhes mostra o aviso da carga', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final carga = EtlCarga.fromJson({
      'id': 5,
      'status': 'SUCCESS',
      'originalFilename': 'EDP_ES.zip',
      'summary': {'avisos': [aviso], 'geodatabase': {'tabelas': {}}},
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CargaDetalhesDialog(carga: carga))));
    expect(find.text(aviso), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
