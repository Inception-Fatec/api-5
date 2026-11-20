import 'package:flutter/material.dart';

import 'package:tecsys_app/core/ajuda/ajuda.dart';
import 'package:tecsys_app/core/ajuda/textos_ajuda.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/projects/ui/comparacao_textos.dart';
import 'package:tecsys_app/features/projects/ui/widgets/comparison/coluna_cenario.dart';
import 'package:tecsys_app/features/projects/ui/widgets/comparison/painel_comparativo.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/data/services/report_service.dart';
import 'package:tecsys_app/features/reports/ui/screens/reports_screen.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';

/// Comparação de 2+ projetos concluídos: no topo, o comparativo (barras,
/// o melhor de cada indicador e a leitura de cada cenário); embaixo, um
/// card por cenário, lado a lado quando cabe, com o Δ para o 1º marcado e o
/// mapa. Tocar num card abre o relatório completo do projeto.
class ProjectComparisonScreen extends StatefulWidget {
  const ProjectComparisonScreen({
    super.key,
    required this.projetos,
    this.service,
    this.mapaBuilder,
    this.abrirRelatorio,
  });

  /// Na ordem da seleção: o primeiro é a referência.
  final List<Project> projetos;
  final ReportService? service;

  /// Mapa de cada cenário; por padrão o [ReportMap] do relatório. Os testes
  /// trocam por um substituto (o mapa baixa tiles da internet).
  final Widget Function(CoverageReport report)? mapaBuilder;

  /// Abre o relatório de um cenário; por padrão a tela de relatório.
  final void Function(BuildContext context, Project projeto)? abrirRelatorio;

  /// Largura mínima de um card para ficarem lado a lado.
  static const larguraMinimaColuna = 300.0;
  static const espaco = AppSpacing.md;

  @override
  State<ProjectComparisonScreen> createState() =>
      _ProjectComparisonScreenState();
}

class _ProjectComparisonScreenState extends State<ProjectComparisonScreen> {
  late final ComparacaoController _controller =
      ComparacaoController(widget.projetos, service: widget.service)..carregar();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _mapa(CoverageReport report) =>
      widget.mapaBuilder?.call(report) ??
      ReportMap(
        report: report,
        interactive: false,
        gatewayMarkers: GatewayMarkerMode.dotsOnly,
      );

  void _abrirRelatorio(Project projeto) {
    final abrir = widget.abrirRelatorio;
    if (abrir != null) return abrir(context, projeto);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(project: projeto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Comparar cenários'),
        actions: const [AjudaBotao(ajuda: TextosAjuda.comparacao)],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            const espaco = ProjectComparisonScreen.espaco;
            final cenarios = _controller.cenarios;
            final n = cenarios.length;
            final util = constraints.maxWidth - 2 * espaco;
            final ladoALado = util >=
                n * ProjectComparisonScreen.larguraMinimaColuna +
                    (n - 1) * espaco;
            final cards = [
              for (var i = 0; i < n; i++)
                ColunaCenario(
                  key: Key('cenario-${cenarios[i].projeto.id}'),
                  cenario: cenarios[i],
                  letra: letraCenario(i),
                  referencia: i == 0,
                  delta: _controller.delta(cenarios[i]),
                  mapa: _mapa,
                  onRecarregar: () => _controller.recarregar(cenarios[i]),
                  onAbrirRelatorio: () => _abrirRelatorio(cenarios[i].projeto),
                ),
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(espaco),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PainelComparativo(controller: _controller),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Cenários', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 2),
                  const Text(
                      'Toque em um cenário para abrir o relatório completo.',
                      style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.sm),
                  if (ladoALado)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(width: espaco),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(height: espaco),
                          cards[i],
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
