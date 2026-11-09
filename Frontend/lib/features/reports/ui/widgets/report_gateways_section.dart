import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_search_field.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// Frações (0..1, sobre o total de pontos) da barra de um gateway:
/// o que já estava coberto antes dele e o que ele acrescentou.
class GatewayBarFractions {
  const GatewayBarFractions(this.previous, this.added);

  final double previous;
  final double added;

  @override
  bool operator ==(Object other) =>
      other is GatewayBarFractions &&
      other.previous == previous &&
      other.added == added;

  @override
  int get hashCode => Object.hash(previous, added);
}

GatewayBarFractions gatewayBarFractions(ReportGateway g, int totalPoints) {
  if (totalPoints <= 0) return const GatewayBarFractions(0, 0);
  final added = (g.newPointsCovered / totalPoints).clamp(0.0, 1.0).toDouble();
  final previousCount = g.cumulativePointsCovered - g.newPointsCovered;
  final previous =
      (previousCount / totalPoints).clamp(0.0, 1.0 - added).toDouble();
  return GatewayBarFractions(previous, added);
}

/// Filtra gateways pelo texto digitado: parte do código (sem diferenciar
/// maiúsculas) ou o número de ordem exato ("3" ou "#3"). Vazio = todos.
List<ReportGateway> filterGateways(List<ReportGateway> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  final order = int.tryParse(q.startsWith('#') ? q.substring(1) : q);
  return all
      .where((g) => g.id.toLowerCase().contains(q) || g.order == order)
      .toList(growable: false);
}

/// Gateways propostos: curva de cobertura acumulada, busca por código e
/// lista paginada (10 por vez) — com 100+ gateways a lista inteira não
/// cabe numa tela. Tocar numa linha leva ao gateway no mapa ([onTap]).
class ReportGatewaysSection extends StatefulWidget {
  const ReportGatewaysSection({
    super.key,
    required this.report,
    required this.onTap,
  });

  final CoverageReport report;
  final ValueChanged<ReportGateway> onTap;

  @override
  State<ReportGatewaysSection> createState() => _ReportGatewaysSectionState();
}

class _ReportGatewaysSectionState extends State<ReportGatewaysSection> {
  String _query = '';
  int _visible = ReportStyles.gatewayPageSize;

  void _setQuery(String value) => setState(() {
        _query = value;
        _visible = ReportStyles.gatewayPageSize;
      });

  @override
  Widget build(BuildContext context) {
    final all = widget.report.gateways;
    final filtered = filterGateways(all, _query);
    final shown = filtered.take(_visible).toList(growable: false);
    final remaining = filtered.length - shown.length;

    return ReportSection(
      title: 'Gateways propostos',
      icon: Icons.cell_tower,
      subtitle: all.isEmpty
          ? null
          : '${formatInt(all.length)} em ordem de escolha: cada um cobre o que '
              'os anteriores não cobriram.',
      child: all.isEmpty
          ? const Text('Nenhum gateway adiciona cobertura neste estudo.',
              style: ReportStyles.rowLabel)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSearchField(
                  hint: 'Buscar por código ou nº do gateway',
                  onChanged: _setQuery,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  filtered.isEmpty
                      ? 'Nenhum gateway encontrado.'
                      : 'Mostrando ${formatInt(shown.length)} de '
                          '${formatInt(filtered.length)}',
                  style: ReportStyles.rowLabel,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  GatewayTile(
                    gateway: shown[i],
                    totalPoints: widget.report.summary.totalPoints,
                    onTap: () => widget.onTap(shown[i]),
                  ),
                ],
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      height: ReportStyles.minTouchSize,
                      child: OutlinedButton(
                        onPressed: () => setState(() =>
                            _visible += ReportStyles.gatewayPageSize),
                        child: Text(
                            'Mostrar mais ${formatInt(remaining < ReportStyles.gatewayPageSize ? remaining : ReportStyles.gatewayPageSize)}'
                            ' (restam ${formatInt(remaining)})'),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const _BarLegend(),
              ],
            ),
    );
  }
}

class GatewayTile extends StatelessWidget {
  const GatewayTile({
    super.key,
    required this.gateway,
    required this.totalPoints,
    required this.onTap,
  });

  final ReportGateway gateway;
  final int totalPoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fractions = gatewayBarFractions(gateway, totalPoints);
    final title = '${gatewayTypeLabel(gateway.type)} ${gateway.id}';
    return InkWell(
      onTap: onTap,
      // Segurar copia as coordenadas (para colar no Google Maps etc.).
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(
            text: formatCoordinates(
                gateway.position.latitude, gateway.position.longitude)));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Coordenadas copiadas.')));
      },
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            CircleAvatar(
              radius: ReportStyles.badgeRadius,
              backgroundColor: ReportStyles.pinColor,
              child: Text('${gateway.order}',
                  style: ReportStyles.pinNumberStyle),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ReportStyles.rowValue),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('+${formatInt(gateway.newPointsCovered)} pts',
                          style: ReportStyles.rowValue
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CoverageBar(fractions: fractions),
                  const SizedBox(height: AppSpacing.xs + 2),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      '${formatPercent(gateway.cumulativeCoveragePercentage)} '
                      'acumulado',
                      textAlign: TextAlign.end,
                      style: ReportStyles.rowLabel,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          formatCoordinates(
                              gateway.position.latitude,
                              gateway.position.longitude),
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class CoverageBar extends StatelessWidget {
  const CoverageBar({required this.fractions});

  final GatewayBarFractions fractions;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pill,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Container(
            height: ReportStyles.barHeight,
            width: w,
            color: ReportStyles.barTrack,
            child: Row(
              children: [
                Container(
                    width: w * fractions.previous,
                    color: ReportStyles.barPrevious),
                Container(
                    width: w * fractions.added, color: ReportStyles.barNew),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BarLegend extends StatelessWidget {
  const _BarLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: ReportStyles.legendDotSize,
                height: ReportStyles.legendDotSize,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(t, style: AppTextStyles.caption),
          ],
        );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        item(ReportStyles.barNew, 'Acrescentado por este gateway'),
        item(ReportStyles.barPrevious, 'Já coberto pelos anteriores'),
      ],
    );
  }
}
