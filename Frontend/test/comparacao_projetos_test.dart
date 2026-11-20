// Comparar projetos: seleção múltipla só de concluídos, colunas lado a lado
// com Δ de cobertura e de gateways, mapa por cenário, card que abre o
// relatório e layout de 400 px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';
import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/projects/ui/comparacao_textos.dart';
import 'package:tecsys_app/features/projects/ui/screens/project_comparison_screen.dart';
import 'package:tecsys_app/features/projects/ui/widgets/comparison/coluna_cenario.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_list_view.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/data/services/report_service.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';

class _ServicoFalso extends ProjectsService {}

class _RelatoriosFalsos implements ReportService {
  _RelatoriosFalsos(this.porId);
  final Map<int, CoverageReport> porId;

  @override
  bool get requiresCompletedProject => true;

  @override
  Future<StatusProjeto?> statusAtual(int projectId) async => null;

  @override
  Future<CoverageReport> carregar(int projectId) async => porId[projectId]!;
}

Project _projeto(int id, {String status = 'SUCESSO', List<String> cidades = const ['3549904']}) =>
    Project(
      id: id,
      name: 'Cenário $id',
      distCode: '391',
      status: status,
      createdById: 1,
      createdAt: DateTime(2026, 1, 1),
      munCodes: cidades,
    );

CoverageReport _relatorio({required double cobertura, required int gateways, int total = 1000}) {
  final atendidos = (total * cobertura / 100).round();
  return CoverageReport(
    summary: ReportSummary(
      totalPoints: total,
      totalCandidates: 50,
      selectedGateways: gateways,
      coveredPoints: atendidos,
      uncoveredPoints: total - atendidos,
      coveragePercentage: cobertura,
      gatewayRangeM: 19313,
    ),
    gateways: const [],
    coveredPoints: PointCloud.fromCompactList(const []),
    uncoveredPoints: PointCloud.fromCompactList(const []),
    filters: null,
  );
}

ProjectsListController _lista(List<Project> projetos) {
  final store = ProjectsStore.forTesting(_ServicoFalso())..projects = projetos;
  return ProjectsListController(store: store);
}

/// Projetos que o card mandou abrir no relatório.
final _abertos = <int>[];

Future<void> _abrirComparacao(WidgetTester tester, Size tela,
    List<Project> projetos, Map<int, CoverageReport> relatorios) async {
  _abertos.clear();
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProjectComparisonScreen(
      projetos: projetos,
      service: _RelatoriosFalsos(relatorios),
      // O ReportMap baixa tiles da internet; aqui basta saber que há um mapa.
      mapaBuilder: (_) => const ColoredBox(
          key: Key('mapa-cenario'), color: Colors.grey, child: SizedBox.expand()),
      abrirRelatorio: (_, p) => _abertos.add(p.id),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecionar 2 → tela com 2 colunas lado a lado e Δ correto', (tester) async {
    final a = _projeto(1), b = _projeto(2);
    final lista = _lista([a, b, _projeto(3, status: 'ENVIADO')]);
    addTearDown(lista.dispose);

    lista.alternarComparacao();
    lista.alternarSelecao(a);
    lista.alternarSelecao(b);
    expect(lista.selecionados.map((p) => p.id), [1, 2]);
    expect(lista.podeAbrirComparacao, isTrue);

    await _abrirComparacao(tester, const Size(1200, 2000), lista.selecionados, {
      1: _relatorio(cobertura: 80, gateways: 5),
      2: _relatorio(cobertura: 85, gateways: 4),
    });

    expect(find.byType(ColunaCenario), findsNWidgets(2));
    final colunaA = tester.getRect(find.byKey(const Key('cenario-1')));
    final colunaB = tester.getRect(find.byKey(const Key('cenario-2')));
    expect(colunaB.top, colunaA.top, reason: 'mesma linha');
    expect(colunaB.left, greaterThan(colunaA.right), reason: 'lado a lado');

    // Δ do cenário B em relação à referência A: 85 − 80 e 4 − 5.
    expect(
        find.descendant(
            of: find.byKey(const Key('delta-cobertura-2')),
            matching: find.text('Δ +5,00 p.p.')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('delta-gateways-2')),
            matching: find.text('Δ −1')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('delta-atendidos-2')),
            matching: find.text('Δ +50')),
        findsOneWidget);
    // A referência não tem Δ; cada cenário tem o próprio mapa.
    expect(find.byKey(const Key('delta-cobertura-1')), findsNothing);
    expect(find.text('Referência'), findsOneWidget);
    expect(find.byKey(const Key('mapa-cenario')), findsNWidgets(2));
  });

  testWidgets('comparativo: melhor de cada indicador e a leitura do cenário', (tester) async {
    await _abrirComparacao(tester, const Size(1200, 2000), [_projeto(1), _projeto(2)], {
      1: _relatorio(cobertura: 80, gateways: 5),
      2: _relatorio(cobertura: 85, gateways: 4),
    });

    expect(tester.widget<Text>(find.byKey(const Key('destaque-Cobertura'))).data, 'maior: B');
    expect(tester.widget<Text>(find.byKey(const Key('destaque-Gateways'))).data, 'menor: B');
    expect(tester.widget<Text>(find.byKey(const Key('leitura-2'))).data,
        'B cobre 5,00 p.p. a mais que A, com 1 gateway a menos.');
    // Mesma área e mesmo total: sem aviso. Sem legenda solta no fim da página.
    expect(find.byKey(const Key('aviso-comparacao')), findsNothing);
    expect(find.byType(ReportLegend), findsNothing);
  });

  testWidgets('tocar no card ou em "Ver relatório completo" abre o relatório', (tester) async {
    await _abrirComparacao(tester, const Size(1200, 2000), [_projeto(1), _projeto(2)], {
      1: _relatorio(cobertura: 80, gateways: 5),
      2: _relatorio(cobertura: 85, gateways: 4),
    });

    await tester.tap(find.descendant(
        of: find.byKey(const Key('cenario-2')), matching: find.text('Cenário 2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('abrir-relatorio-1')));
    await tester.pump();
    expect(_abertos, [2, 1]);
  });

  testWidgets('cidades diferentes: avisa que gateways não se comparam direto', (tester) async {
    await _abrirComparacao(tester, const Size(1200, 2000), [
      _projeto(1, cidades: ['3508504']),
      _projeto(2, cidades: ['3549904']),
    ], {
      1: _relatorio(cobertura: 100, gateways: 4, total: 206),
      2: _relatorio(cobertura: 100, gateways: 2, total: 1612),
    });

    expect(find.byKey(const Key('aviso-comparacao')), findsOneWidget);
    expect(find.textContaining('áreas diferentes'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('destaque-Cobertura'))).data, 'empate');
    expect(tester.widget<Text>(find.byKey(const Key('leitura-2'))).data,
        'B tem a mesma cobertura que A, com 2 gateways a menos.');
  });

  testWidgets('projeto Enviado não é selecionável', (tester) async {
    final lista = _lista([_projeto(1), _projeto(3, status: 'ENVIADO')]);
    addTearDown(lista.dispose);
    lista.alternarComparacao();

    expect(lista.alternarSelecao(_projeto(3, status: 'ENVIADO')), isFalse);
    expect(lista.estaSelecionado(3), isFalse);

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: lista,
            builder: (_, __) => ProjectsListView(
              controller: lista,
              grid: false,
              onNewProject: () {},
              onOpenProject: (_) {},
            ),
          ),
        ),
      ),
    ));

    // Caixa de marcar desativada e o toque não marca: só avisa.
    expect(tester.widget<Checkbox>(find.byKey(const Key('comparar-3'))).onChanged, isNull);
    await tester.tap(find.text('Cenário 3'));
    await tester.pump();
    expect(lista.estaSelecionado(3), isFalse);
    expect(find.text('Só projetos concluídos podem ser comparados.'), findsOneWidget);

    // O concluído marca normalmente.
    await tester.tap(find.text('Cenário 1'));
    await tester.pump();
    expect(lista.estaSelecionado(1), isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const Key('comparar-1'))).value, isTrue);
  });

  testWidgets('largura 400 px → colunas empilhadas sem rolagem horizontal', (tester) async {
    await _abrirComparacao(tester, const Size(400, 3200), [_projeto(1), _projeto(2)], {
      1: _relatorio(cobertura: 92.5, gateways: 7),
      2: _relatorio(cobertura: 90, gateways: 9),
    });

    expect(tester.takeException(), isNull, reason: 'nada estoura a largura');
    final colunaA = tester.getRect(find.byKey(const Key('cenario-1')));
    final colunaB = tester.getRect(find.byKey(const Key('cenario-2')));
    expect(colunaB.top, greaterThanOrEqualTo(colunaA.bottom), reason: 'empilhadas');
    expect(colunaA.right, lessThanOrEqualTo(400));
    expect(colunaB.right, lessThanOrEqualTo(400));
    expect(
        find.byWidgetPredicate((w) =>
            w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.horizontal),
        findsNothing);
    expect(find.text('Δ −2,50 p.p.'), findsWidgets);
    expect(find.text('Δ +2'), findsWidgets);
  });

  test('Δ é sempre em relação à referência (1º marcado)', () async {
    final controller = ComparacaoController(
      [_projeto(1), _projeto(2), _projeto(3)],
      service: _RelatoriosFalsos({
        1: _relatorio(cobertura: 70, gateways: 10),
        2: _relatorio(cobertura: 75.5, gateways: 8),
        3: _relatorio(cobertura: 70, gateways: 12),
      }),
    );
    addTearDown(controller.dispose);
    await controller.carregar();

    expect(controller.delta(controller.cenarios[0]), isNull);
    final b = controller.delta(controller.cenarios[1])!;
    final c = controller.delta(controller.cenarios[2])!;
    expect((b.coberturaPp, b.gateways, b.atendidos), (5.5, -2, 55));
    expect((c.coberturaPp, c.gateways, c.atendidos), (0.0, 2, 0));
    expect(b.porGateway, closeTo(755 / 8 - 70, 1e-9));
    expect(formatarDeltaCobertura(c.coberturaPp), '0,00 p.p.');
    expect(formatarDeltaCobertura(-1.256), '−1,26 p.p.');
    expect(formatarDeltaGateways(0), '0');
    expect(formatarDeltaGateways(-1406), '−1.406');
    expect(leituraCenario('C', c), 'C tem a mesma cobertura que A, com 2 gateways a mais.');
  });
}
