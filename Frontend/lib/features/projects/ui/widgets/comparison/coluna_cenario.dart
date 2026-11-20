import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/projects/ui/widgets/comparison/chip_delta.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map_screen.dart';

/// Um cenário da comparação: indicadores com o Δ para a referência e o
/// mapa. O card inteiro abre o relatório completo do projeto.
class ColunaCenario extends StatelessWidget {
  const ColunaCenario({
    super.key,
    required this.cenario,
    required this.letra,
    required this.referencia,
    required this.delta,
    required this.mapa,
    required this.onRecarregar,
    required this.onAbrirRelatorio,
  });

  final CenarioComparado cenario;
  final String letra;
  final bool referencia;
  final DeltaCenario? delta;
  final Widget Function(CoverageReport report) mapa;
  final VoidCallback onRecarregar;
  final VoidCallback onAbrirRelatorio;

  @override
  Widget build(BuildContext context) {
    final p = cenario.projeto;
    final relatorio = cenario.relatorio;
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xl,
        side: BorderSide(
            color: referencia ? AppColors.primary : AppColors.border,
            width: referencia ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onAbrirRelatorio,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecalho(p),
              const SizedBox(height: AppSpacing.sm),
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
              const Divider(height: AppSpacing.lg, color: AppColors.divider),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('abrir-relatorio-${p.id}'),
                  onPressed: onAbrirRelatorio,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Ver relatório completo'),
                  iconAlignment: IconAlignment.start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(Project p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: referencia ? AppColors.primary : AppColors.chipBg,
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
                  if (p.munCodes.isNotEmpty) IbgeService.rotulosMunicipios(p.munCodes),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
                color: AppColors.chipBg, borderRadius: AppRadius.pill),
            child: const Text('Referência',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
      ],
    );
  }

  List<Widget> _conteudo(BuildContext context, CoverageReport r) {
    final s = r.summary;
    final id = cenario.projeto.id;
    final d = delta;
    return [
      _Indicador(
        rotulo: 'Cobertura',
        valor: formatPercent(s.coveragePercentage),
        delta: d == null
            ? null
            : ChipDelta.cobertura(d.coberturaPp, key: Key('delta-cobertura-$id')),
      ),
      _Indicador(
        rotulo: 'Gateways',
        valor: formatInt(s.selectedGateways),
        delta: d == null
            ? null
            : ChipDelta.gateways(d.gateways, key: Key('delta-gateways-$id')),
      ),
      _Indicador(
        rotulo: 'Consumidores atendidos',
        valor: '${formatInt(s.coveredPoints)} de ${formatInt(s.totalPoints)}',
        delta: d == null
            ? null
            : ChipDelta.atendidos(d.atendidos, key: Key('delta-atendidos-$id')),
      ),
      _Indicador(
        rotulo: 'Consumidores por gateway',
        valor: s.selectedGateways > 0 ? formatDecimal(consumidoresPorGateway(s)) : '—',
        delta: d == null
            ? null
            : ChipDelta.porGateway(d.porGateway, key: Key('delta-por-gateway-$id')),
      ),
      _Indicador(
        rotulo: 'Perfil de gateway',
        valor: s.assumptions.gatewayProfile ?? '—',
      ),
      if (referencia)
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('Base de comparação: os Δ dos outros cenários são em relação a este.',
              style: AppTextStyles.micro),
        ),
      const SizedBox(height: AppSpacing.md),
      ClipRRect(
        borderRadius: AppRadius.md,
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              // Só imagem: o toque no mapa vale como toque no card.
              Positioned.fill(child: IgnorePointer(child: mapa(r))),
              Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Material(
                  color: AppColors.surface,
                  elevation: 2,
                  borderRadius: AppRadius.pill,
                  child: InkWell(
                    key: Key('expandir-mapa-$id'),
                    borderRadius: AppRadius.pill,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            ReportMapScreen(report: r, title: cenario.projeto.name))),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Expandir mapa',
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
      const SizedBox(height: AppSpacing.xs + 2),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: 4,
        children: [
          _ItemLegenda(cor: ReportLegend.corMancha, texto: 'Área atendida'),
          const _ItemLegenda(cor: ReportStyles.pinColor, texto: 'Gateway'),
          const _ItemLegenda(cor: ReportStyles.uncoveredPointColor, texto: 'Sem cobertura'),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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

class _ItemLegenda extends StatelessWidget {
  const _ItemLegenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: AppTextStyles.micro),
      ],
    );
  }
}
