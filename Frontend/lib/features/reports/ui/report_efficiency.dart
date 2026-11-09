import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';

/// Metas de cobertura (%) mostradas em "Quantos gateways valem a pena".
/// Escolha comercial/visual, não parâmetro de RF.
const coverageTargets = [50.0, 80.0, 90.0, 95.0, 99.0];

/// Primeiro ponto da lista de gateways em que a cobertura acumulada
/// atinge [target] %.
class CoverageMilestone {
  const CoverageMilestone({
    required this.target,
    required this.gatewayCount,
    required this.achievedPercent,
    required this.shareOfGateways,
  });

  final double target;

  /// Quantos gateways (os primeiros, em ordem de escolha) são necessários.
  final int gatewayCount;

  /// Cobertura acumulada real nesse ponto (>= [target]).
  final double achievedPercent;

  /// Fração (0..1) da rede proposta que esses gateways representam.
  final double shareOfGateways;
}

/// Metas atingidas, em ordem crescente. Metas que a rede nunca alcança
/// não aparecem. [gateways] precisa estar em ordem de escolha.
List<CoverageMilestone> coverageMilestones(
  List<ReportGateway> gateways, {
  List<double> targets = coverageTargets,
}) {
  final result = <CoverageMilestone>[];
  for (final target in targets) {
    final index = gateways
        .indexWhere((g) => g.cumulativeCoveragePercentage >= target);
    if (index < 0) continue;
    result.add(CoverageMilestone(
      target: target,
      gatewayCount: index + 1,
      achievedPercent: gateways[index].cumulativeCoveragePercentage,
      shareOfGateways: (index + 1) / gateways.length,
    ));
  }
  return result;
}

/// Tamanho da faixa conforme a quantidade de gateways: 0 = não vale
/// quebrar em faixas (10 gateways ou menos).
int stepFor(int gatewayCount) {
  if (gatewayCount <= 10) return 0;
  if (gatewayCount <= 25) return 5;
  if (gatewayCount <= 200) return 10;
  if (gatewayCount <= 500) return 25;
  return 50;
}

/// Uma faixa de gateways (ex.: do 11º ao 20º) e o que ela acrescenta.
class CoverageStep {
  const CoverageStep({
    required this.from,
    required this.to,
    required this.cumulativePercent,
    required this.gainPercent,
    required this.newPoints,
  });

  /// Posição inicial e final (1-based, inclusive) na ordem de escolha.
  final int from;
  final int to;

  /// Cobertura acumulada ao fim da faixa e quanto a faixa acrescentou
  /// (pontos percentuais).
  final double cumulativePercent;
  final double gainPercent;

  /// Pontos novos atendidos pela faixa.
  final int newPoints;

  String get label => from == to ? '$from' : '$from–$to';
}

List<CoverageStep> coverageSteps(List<ReportGateway> gateways, {int? step}) {
  final size = step ?? stepFor(gateways.length);
  if (size <= 0 || gateways.isEmpty) return const [];
  final steps = <CoverageStep>[];
  for (var start = 0; start < gateways.length; start += size) {
    final end = (start + size < gateways.length) ? start + size : gateways.length;
    final before = start == 0
        ? 0.0
        : gateways[start - 1].cumulativeCoveragePercentage;
    final after = gateways[end - 1].cumulativeCoveragePercentage;
    var points = 0;
    for (var i = start; i < end; i++) {
      points += gateways[i].newPointsCovered;
    }
    steps.add(CoverageStep(
      from: start + 1,
      to: end,
      cumulativePercent: after,
      gainPercent: (after - before).clamp(0.0, 100.0).toDouble(),
      newPoints: points,
    ));
  }
  return steps;
}

/// Quantos gateways atendem [maxPoints] ponto(s) novo(s) ou menos: os que
/// dificilmente compensam o custo de instalação.
int lowGainGateways(List<ReportGateway> gateways, {int maxPoints = 1}) =>
    gateways.where((g) => g.newPointsCovered <= maxPoints).length;
