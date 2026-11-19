import 'package:flutter/material.dart';

import 'package:tecsys_app/core/ajuda/ajuda.dart';
import 'package:tecsys_app/core/ajuda/textos_ajuda.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/data/services/report_service.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map_screen.dart';

/// Δ de cobertura em pontos percentuais: "+5,00 p.p.", "−1,25 p.p.".
String formatarDeltaCobertura(double pp) {
  final arredondado = double.parse(pp.toStringAsFixed(2));
  if (arredondado == 0) return '0,00 p.p.';
  return '${arredondado > 0 ? '+' : '−'}'
      '${formatDecimal(arredondado.abs(), digits: 2)} p.p.';
}

/// Δ de gateways: "+2", "−3", "0".
String formatarDeltaGateways(int d) =>
    d == 0 ? '0' : '${d > 0 ? '+' : '−'}${d.abs()}';

/// Letra do cenário na ordem em que foi marcado (A = referência).
String letraCenario(int i) => String.fromCharCode(65 + i % 26);

/// Comparação lado a lado de 2+ projetos concluídos: indicadores, Δ de
/// cobertura e de gateways em relação ao 1º marcado e o mapa de cada um.
class ProjectComparisonScreen extends StatefulWidget {
  const ProjectComparisonScreen({
    super.key,
    required this.projetos,
    this.service,
    this.mapaBuilder,
  });

  /// Na ordem da seleção: o primeiro é a referência.
  final List<Project> projetos;
  final ReportService? service;

  /// Mapa de cada cenário; por padrão o [ReportMap] do relatório. Os testes
  /// trocam por um substituto (o mapa baixa tiles da internet).
  final Widget Function(CoverageReport report)? mapaBuilder;

  /// Largura mínima de uma coluna para ficarem lado a lado.
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
            final colunas = [
              for (var i = 0; i < n; i++)
                ColunaCenario(
                  key: Key('cenario-${cenarios[i].projeto.id}'),
                  cenario: cenarios[i],
                  letra: letraCenario(i),
                  referencia: i == 0,
                  delta: _controller.delta(cenarios[i]),
                  mapa: _mapa,
                  onRecarregar: () => _controller.recarregar(cenarios[i]),
                ),
            ];
            final referencia = _controller.referencia.relatorio;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(espaco),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResumoComparacao(controller: _controller),
                  const SizedBox(height: espaco),
                  if (ladoALado)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(width: espaco),
                          Expanded(child: colunas[i]),
                        ],
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(height: espaco),
                          colunas[i],
                        ],
                      ],
                    ),
                  if (referencia != null) ...[
                    const SizedBox(height: espaco),
                    ReportLegend(
                        rangeM: referencia.summary.gatewayRangeM,
                        assumptions: referencia.summary.assumptions),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Destaque no topo: o Δ de cada cenário em relação à referência.
class _ResumoComparacao extends StatelessWidget {
  const _ResumoComparacao({required this.controller});

  final ComparacaoController controller;

  @override
  Widget build(BuildContext context) {
    final cenarios = controller.cenarios;
    final linhas = <Widget>[
      for (var i = 1; i < cenarios.length; i++)
        if (controller.delta(cenarios[i]) case final d?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${letraCenario(i)} · ${cenarios[i].projeto.name}',
                    style: AppTextStyles.sectionLabel),
                ChipDelta.cobertura(d.coberturaPp),
                ChipDelta.gateways(d.gateways),
              ],
            ),
          ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diferença em relação a A · ${controller.referencia.projeto.name}',
            style: AppTextStyles.cardTitle,
          ),
          if (linhas.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text('Carregando os relatórios...',
                  style: AppTextStyles.bodyMuted),
            )
          else
            ...linhas,
        ],
      ),
    );
  }
}

/// Uma coluna da comparação: cabeçalho, indicadores com Δ e mapa.
class ColunaCenario extends StatelessWidget {
  const ColunaCenario({
    super.key,
    required this.cenario,
    required this.letra,
    required this.referencia,
    required this.delta,
    required this.mapa,
    required this.onRecarregar,
  });

  final CenarioComparado cenario;
  final String letra;
  final bool referencia;
  final DeltaCenario? delta;
  final Widget Function(CoverageReport report) mapa;
  final VoidCallback onRecarregar;

  @override
  Widget build(BuildContext context) {
    final p = cenario.projeto;
    final relatorio = cenario.relatorio;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl,
        border: Border.all(
            color: referencia ? AppColors.primary : AppColors.border,
            width: referencia ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    referencia ? AppColors.primary : AppColors.chipBg,
                child: Text(letra,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: referencia ? Colors.white : AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle),
                    Text(
                      [
                        nomeDistribuidora(p.distCode),
                        if (p.munCodes.isNotEmpty)
                          IbgeService.rotulosMunicipios(p.munCodes),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (referencia)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                      color: AppColors.chipBg, borderRadius: AppRadius.pill),
                  child: const Text('Referência',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (cenario.erro != null) ...[
            Text(cenario.erro!, style: AppTextStyles.bodyError),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                  onPressed: onRecarregar, child: const Text('Tentar de novo')),
            ),
          ] else if (relatorio == null)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._conteudo(context, relatorio),
        ],
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context, CoverageReport r) {
    final s = r.summary;
    final id = cenario.projeto.id;
    return [
      _Indicador(
        rotulo: 'Cobertura',
        valor: formatPercent(s.coveragePercentage),
        delta: delta == null
            ? null
            : ChipDelta.cobertura(delta!.coberturaPp,
                key: Key('delta-cobertura-$id')),
      ),
      _Indicador(
        rotulo: 'Gateways',
        valor: formatInt(s.selectedGateways),
        delta: delta == null
            ? null
            : ChipDelta.gateways(delta!.gateways,
                key: Key('delta-gateways-$id')),
      ),
      _Indicador(
        rotulo: 'Consumidores atendidos',
        valor: '${formatInt(s.coveredPoints)} de ${formatInt(s.totalPoints)}',
      ),
      _Indicador(
        rotulo: 'Consumidores por gateway',
        valor: s.selectedGateways > 0
            ? formatDecimal(s.coveredPoints / s.selectedGateways)
            : '—',
      ),
      _Indicador(
        rotulo: 'Perfil de gateway',
        valor: s.assumptions.gatewayProfile ?? '—',
      ),
      const SizedBox(height: AppSpacing.md),
      ClipRRect(
        borderRadius: AppRadius.md,
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned.fill(child: mapa(r)),
              // Toque abre o mapa interativo em tela cheia.
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'Abrir o mapa de ${cenario.projeto.name}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ReportMapScreen(
                            report: r, title: cenario.projeto.name))),
                  ),
                ),
              ),
              const Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: IgnorePointer(
                  child: Material(
                    color: AppColors.surface,
                    elevation: 2,
                    borderRadius: AppRadius.pill,
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Expandir',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.rotulo, required this.valor, this.delta});

  final String rotulo;
  final String valor;
  final Widget? delta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: 4,
        children: [
          Text(rotulo, style: AppTextStyles.bodyMuted),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(valor,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              if (delta != null) ...[
                const SizedBox(width: AppSpacing.sm),
                delta!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Selo do Δ: verde quando o cenário é melhor que a referência (mais
/// cobertura, menos gateways), vermelho quando é pior, cinza quando igual.
class ChipDelta extends StatelessWidget {
  const ChipDelta._({super.key, required this.texto, required this.sinal});

  /// Mais cobertura é melhor.
  factory ChipDelta.cobertura(double pp, {Key? key}) {
    final texto = formatarDeltaCobertura(pp);
    return ChipDelta._(
        key: key, texto: texto, sinal: texto.startsWith('0') ? 0 : pp.sign.toInt());
  }

  /// Menos gateways é melhor.
  factory ChipDelta.gateways(int d, {Key? key}) =>
      ChipDelta._(key: key, texto: formatarDeltaGateways(d), sinal: -d.sign);

  final String texto;

  /// 1 = melhor que a referência, -1 = pior, 0 = igual.
  final int sinal;

  @override
  Widget build(BuildContext context) {
    final cor = switch (sinal) {
      > 0 => AppColors.success,
      < 0 => AppColors.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
      ),
      child: Text('Δ $texto',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: cor)),
    );
  }
}
