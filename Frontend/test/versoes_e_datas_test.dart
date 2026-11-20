// Data de criação nos cards e "Voltar para esta versão" no histórico.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/ui/widgets/project_versions_sheet.dart';

ProjectVersion _versao(int id, String data) => ProjectVersion.fromJson({
      'id': id,
      'created_at': data,
      'filter_params': {'mun_codes': ['3549904']},
    });

Project _projeto(String status) => Project(
      id: 7,
      name: 'P',
      distCode: '391',
      status: status,
      createdById: 1,
      createdAt: DateTime(2026, 1, 1),
    );

Future<void> _abrir(WidgetTester tester, ProjectVersionsSheet folha) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: folha)));
}

void main() {
  test('data de criação no formato do backend vira a data do card', () {
    final p = Project.fromJson({
      'id': 1,
      'name': 'P',
      'dist_code': '391',
      'created_at': '03/10/2026 14:05:00',
      'updated_at': '05/10/2026 08:00:00',
    });
    expect(p.createdAt, DateTime(2026, 10, 3, 14, 5));
    expect(p.dataFormatada, '03/10/2026');
    expect(p.updatedAt, DateTime(2026, 10, 5, 8));
  });

  testWidgets('versão antiga tem "Voltar para esta versão"; a atual não',
      (tester) async {
    final versoes = [_versao(3, '09/11/2026 10:00:00'), _versao(1, '01/11/2026 10:00:00')];
    ProjectVersion? restaurada;
    Project? devolvido;
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              devolvido = await showModalBottomSheet<Project>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProjectVersionsSheet(
                  versoes: versoes,
                  onRestaurar: (v) async {
                    restaurada = v;
                    return _projeto('ENVIADO');
                  },
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('restaurar-versao-3')), findsNothing);
    await tester.tap(find.byKey(const Key('restaurar-versao-1')));
    await tester.pumpAndSettle();
    expect(find.text('Voltar para a versão 1?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmar-restaurar')));
    await tester.pumpAndSettle();

    expect(restaurada?.id, 1);
    expect(devolvido?.status, 'ENVIADO', reason: 'a folha fecha com o projeto');
    expect(find.byType(ProjectVersionsSheet), findsNothing);
  });

  testWidgets('depois de voltar: a versão antiga fica "Em uso" e a mais nova pode voltar a ser usada',
      (tester) async {
    final versoes = [
      _versao(3, '09/11/2026 10:00:00'),
      ProjectVersion.fromJson({
        'id': 1,
        'created_at': '01/11/2026 10:00:00',
        'filter_params': const {},
        'current': true,
      }),
    ];
    await _abrir(
      tester,
      ProjectVersionsSheet(
        versoes: versoes,
        onRestaurar: (_) async => _projeto('ENVIADO'),
      ),
    );
    expect(ProjectVersion.versaoEmUso(versoes)?.id, 1);
    expect(find.text('Em uso'), findsOneWidget);
    expect(find.byKey(const Key('restaurar-versao-1')), findsNothing);
    expect(find.byKey(const Key('restaurar-versao-3')), findsOneWidget);
    expect(find.text('Versão 2'), findsOneWidget, reason: 'numeração não muda');
  });

  test('backend sem "current": a versão em uso é a mais recente', () {
    final versoes = [_versao(3, '09/11/2026 10:00:00'), _versao(1, '01/11/2026 10:00:00')];
    expect(ProjectVersion.versaoEmUso(versoes)?.id, 3);
    expect(ProjectVersion.versaoEmUso(const []), isNull);
  });

  testWidgets('cancelar a confirmação não restaura', (tester) async {
    var chamou = false;
    await _abrir(
      tester,
      ProjectVersionsSheet(
        versoes: [_versao(3, '09/11/2026 10:00:00'), _versao(1, '01/11/2026 10:00:00')],
        onRestaurar: (_) async {
          chamou = true;
          return _projeto('ENVIADO');
        },
      ),
    );
    await tester.tap(find.byKey(const Key('restaurar-versao-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(chamou, isFalse);
  });

  testWidgets('erro ao restaurar aparece na folha', (tester) async {
    await _abrir(
      tester,
      ProjectVersionsSheet(
        versoes: [_versao(3, '09/11/2026 10:00:00'), _versao(1, '01/11/2026 10:00:00')],
        onRestaurar: (_) async => throw Exception('motor fora do ar'),
      ),
    );
    await tester.tap(find.byKey(const Key('restaurar-versao-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-restaurar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível voltar para a versão 1'),
        findsOneWidget);
  });

  testWidgets('calculando: sem o botão e com o motivo', (tester) async {
    await _abrir(
      tester,
      ProjectVersionsSheet(
        versoes: [_versao(3, '09/11/2026 10:00:00'), _versao(1, '01/11/2026 10:00:00')],
        motivoSemRestaurar: 'Aguarde o cálculo atual terminar para voltar a uma versão.',
      ),
    );
    expect(find.byKey(const Key('restaurar-versao-1')), findsNothing);
    expect(find.byKey(const Key('motivo-sem-restaurar')), findsOneWidget);
  });
}
