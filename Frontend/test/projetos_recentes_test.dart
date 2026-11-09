// #TG-88: seção "Recentes" da tela de projetos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';
import 'package:tecsys_app/features/projects/ui/widgets/project_versions_sheet.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_recent_section.dart';

/// Não chama o backend.
class _ServicoFalso extends ProjectsService {
  final registrados = <int>[];

  @override
  Future<void> registrarAtividade(int id) async => registrados.add(id);
}

Project _projeto(int id, DateTime atividade, {String status = 'SUCESSO'}) =>
    Project(
      id: id,
      name: 'Projeto $id',
      distCode: '391',
      status: status,
      createdById: 1,
      createdAt: DateTime(2026, 1, 1),
      lastActivityAt: atividade,
    );

void main() {
  test('lê last_activity_at do backend (ISO 8601)', () {
    final p = Project.fromJson({
      'id': 3,
      'name': 'P',
      'dist_code': '391',
      'last_activity_at': '2026-11-09T12:00:00Z',
    });
    expect(p.lastActivityAt, DateTime.utc(2026, 11, 9, 12).toLocal());
  });

  // CT3: 7 projetos → só 5, em ordem de atividade
  test('Recentes: no máximo 5, da atividade mais recente para a mais antiga', () {
    final store = ProjectsStore.forTesting(_ServicoFalso());
    store.projects = [
      for (var i = 1; i <= 7; i++) _projeto(i, DateTime(2026, 11, i)),
    ];
    expect(store.recentes.map((p) => p.id), [7, 6, 5, 4, 3]);
  });

  // CT1: abrir o relatório de um projeto antigo → ele vai para o 1º lugar
  test('abrir um projeto antigo coloca ele em 1º nos Recentes', () async {
    final servico = _ServicoFalso();
    final store = ProjectsStore.forTesting(servico);
    store.projects = [
      for (var i = 1; i <= 7; i++) _projeto(i, DateTime(2026, 11, i)),
    ];

    await store.registrarAtividade(1, agora: DateTime(2026, 11, 9));

    expect(store.recentes.first.id, 1);
    expect(servico.registrados, [1]);
  });

  // CT2: sem projetos → seção oculta
  testWidgets('sem projetos a seção não aparece', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectsRecentSection(projetos: const [], onOpen: (_) {}),
      ),
    ));
    expect(find.text('Recentes'), findsNothing);
  });

  // CT4: 400 px de largura, sem estouro nem rolagem lateral
  testWidgets('cabe em 400 px de largura', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final longo = Project(
      id: 9,
      name: 'Projeto com um nome bem comprido para testar o corte do texto',
      distCode: '391',
      status: 'PROCESSANDO',
      createdById: 1,
      createdAt: DateTime(2026, 11, 9),
    );
    Project? aberto;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectsRecentSection(
          projetos: [longo, _projeto(1, DateTime(2026, 11, 8))],
          onOpen: (p) => aberto = p,
          agora: DateTime(2026, 11, 9, 12),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Recentes'), findsOneWidget);
    await tester.tap(find.textContaining('nome bem comprido'));
    expect(aberto?.id, 9);
  });

  test('texto de quando foi a atividade', () {
    final agora = DateTime(2026, 11, 9, 12);
    expect(ProjectsRecentSection.quando(agora, agora), 'agora');
    expect(ProjectsRecentSection.quando(DateTime(2026, 11, 9, 11, 30), agora), 'há 30 min');
    expect(ProjectsRecentSection.quando(DateTime(2026, 11, 8, 10), agora), 'ontem');
    expect(ProjectsRecentSection.quando(DateTime(2026, 11, 1), agora), '01/11/2026');
  });

  test('resumo de uma versão mostra data, filtros e área (CA4 da US #19)', () {
    final linhas = ProjectVersionsSheet.resumo(ProjectVersion.fromJson({
      'id': 2,
      'created_at': '09/11/2026 09:30:00',
      'filter_params': {
        'mun_codes': ['3549904'],
        'target_layers': ['baixo'],
        'bairro_names': ['CENTRO'],
      },
      'polygon': {
        'type': 'Polygon',
        'coordinates': [
          [[-45.9, -23.2], [-45.8, -23.2], [-45.8, -23.1], [-45.9, -23.2]]
        ],
      },
    }));
    final mapa = {for (final (r, v) in linhas) r: v};
    expect(mapa['Área desenhada'], '1 área');
    expect(mapa['Tensão'], 'Baixo');
    expect(mapa['Bairro'], 'CENTRO');
    expect(mapa['Cidades'], '3549904');
  });
}
