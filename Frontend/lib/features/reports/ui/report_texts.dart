import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_efficiency.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';

/// Textos do relatório, montados a partir dos dados (sem widgets, para
/// poderem ser testados direto).

/// Municípios com dados carregados hoje (mesmos códigos IBGE de
/// `MapRegions`). Código desconhecido aparece como o próprio código.
const Map<String, String> _municipios = {
  '3549904': 'São José dos Campos',
  '3508504': 'Caçapava',
};

const Map<String, String> _niveis = {
  'ALTO': 'Alta',
  'MEDIO': 'Média',
  'BAIXO': 'Baixa',
};

/// "a", "a e b", "a, b e c".
String joinList(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
}

/// Frase de abertura do relatório (o que o estudo responde).
String reportIntro(ReportSummary summary) =>
    'Estudo simulado dos pontos onde instalar gateways para atender o maior '
    'número de pontos de interesse com o menor número de equipamentos. '
    'Cada gateway atende pontos a até ${formatRange(summary.gatewayRangeM)}.';

/// Um parâmetro do estudo (rótulo + valor) para a ficha do relatório.
class ReportParam {
  const ReportParam(this.label, this.value);

  final String label;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is ReportParam && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => '$label: $value';
}

/// Parâmetros do cálculo, um por filtro usado. [f] nulo (o servidor não
/// informou) devolve lista vazia — a tela mostra um aviso, sem afirmar
/// nada; sem filtros devolve uma linha dizendo que toda a base entrou.
List<ReportParam> filterEntries(ReportFilters? f) {
  if (f == null) return const [];
  if (f.isEmpty) {
    return const [ReportParam('Filtros', 'Nenhum — toda a base considerada')];
  }
  return [
    if (f.distCodes.isNotEmpty)
      ReportParam('Distribuidora',
          joinList(f.distCodes.map(nomeDistribuidora).toList())),
    if (f.munCodes.isNotEmpty)
      ReportParam('Municípios',
          joinList(f.munCodes.map((c) => _municipios[c] ?? c).toList())),
    if (f.targetLevels.isNotEmpty)
      ReportParam('Tensão dos pontos',
          joinList(f.targetLevels.map((l) => _niveis[l] ?? l).toList())),
    if (f.bairroNames.isNotEmpty)
      ReportParam('Bairros', joinList(f.bairroNames)),
    if (f.conjCodes.isNotEmpty)
      ReportParam('Conjuntos elétricos', joinList(f.conjCodes)),
    if (f.subCodes.isNotEmpty)
      ReportParam('Subestações', joinList(f.subCodes)),
    if (f.clasSub.isNotEmpty)
      ReportParam('Classes de subgrupo', joinList(f.clasSub)),
    if (f.cnaeCodes.isNotEmpty) ReportParam('CNAE', joinList(f.cnaeCodes)),
    if (f.hasPolygon) const ReportParam('Área', 'Desenhada no mapa'),
  ];
}

/// Rótulo do tipo de gateway candidato.
String gatewayTypeLabel(String? type) {
  switch (type) {
    case 'SUB':
      return 'Subestação';
    case null:
    case '':
      return 'Gateway';
    default:
      return type; // UNTRMT / UNTRAT: o código é o nome usado no setor
  }
}

/// Peso visual de uma observação da "Leitura do resultado".
enum InsightKind { success, info, warning }

class ReportInsight {
  const ReportInsight(this.kind, this.text);

  final InsightKind kind;
  final String text;
}

/// Frases de leitura do resultado, calculadas só a partir dos dados do
/// relatório (nada inventado). Estudo sem pontos não tem leitura.
List<ReportInsight> buildInsights(CoverageReport report) {
  final s = report.summary;
  if (s.totalPoints == 0) return const [];

  final insights = <ReportInsight>[];
  final n = report.gateways.length;
  final range = formatRange(s.gatewayRangeM);

  if (n == 0) {
    insights.add(const ReportInsight(InsightKind.warning,
        'Nenhum gateway candidato adiciona cobertura para estes pontos.'));
  } else {
    final gateways = n == 1 ? '1 gateway' : '$n gateways';
    insights.add(ReportInsight(
      s.uncoveredPoints == 0 ? InsightKind.success : InsightKind.info,
      'Com $gateways, ${formatPercent(s.coveragePercentage)} dos pontos '
      '(${formatInt(s.coveredPoints)} de ${formatInt(s.totalPoints)}) '
      'são atendidos (gateways com alcance de $range, relevo considerado).',
    ));
  }

  if (n >= 2) {
    final first = report.gateways.first;
    final rest = s.coveredPoints - first.cumulativePointsCovered;
    insights.add(ReportInsight(
      InsightKind.info,
      'O gateway ${first.order} sozinho atende '
      '${formatPercent(first.cumulativeCoveragePercentage)} dos pontos; '
      'os outros ${n - 1} acrescentam '
      '${formatInt(rest < 0 ? 0 : rest)} pontos.',
    ));
  }

  if (n >= 5) {
    final milestone = coverageMilestones(report.gateways, targets: const [80.0])
        .firstOrNull;
    if (milestone != null && milestone.gatewayCount < n) {
      final rest = n - milestone.gatewayCount;
      insights.add(ReportInsight(
        InsightKind.info,
        'Os primeiros ${milestone.gatewayCount} gateways '
        '(${formatDecimal(100 * milestone.shareOfGateways)}% da rede) já '
        'atendem ${formatPercent(milestone.achievedPercent)} dos pontos; os '
        'outros $rest acrescentam '
        '${formatDecimal(s.coveragePercentage - milestone.achievedPercent)} '
        'pontos percentuais.',
      ));
    }
    final low = lowGainGateways(report.gateways);
    if (low > 0) {
      insights.add(ReportInsight(
        InsightKind.warning,
        '${formatInt(low)} ${low == 1 ? 'gateway atende' : 'gateways atendem'} '
        'apenas 1 ponto novo cada: avalie se compensam o investimento.',
      ));
    }
  }

  final u = s.uncoveredPoints;
  if (u > 0) {
    insights.add(ReportInsight(
      InsightKind.warning,
      '${formatInt(u)} ${u == 1 ? 'ponto ficou' : 'pontos ficaram'} sem '
      'cobertura: nenhum dos ${formatInt(s.totalCandidates)} candidatos '
      'avaliados ${u == 1 ? 'o alcança' : 'os alcança'}. Avalie novos '
      'candidatos nessa região.',
    ));
  }
  return insights;
}

/// Selo de leitura rápida da cobertura. Usa as mesmas faixas da cor
/// ([ReportStyles.coverageGoodFrom] / [ReportStyles.coverageMediumFrom]).
String coverageLabel(double percentage) {
  if (percentage >= ReportStyles.coverageGoodFrom) return 'Cobertura alta';
  if (percentage >= ReportStyles.coverageMediumFrom) return 'Cobertura média';
  return 'Cobertura baixa';
}

/// Linhas da ficha "Dados do cálculo" (também usadas no PDF). Valores
/// derivados só dos números do `summary`; divisão por zero vira "-".
List<ReportParam> dataRows(ReportSummary s) {
  final perGateway = s.selectedGateways > 0
      ? formatDecimal(s.coveredPoints / s.selectedGateways)
      : '-';
  final used = s.totalCandidates > 0
      ? '${formatInt(s.selectedGateways)} de ${formatInt(s.totalCandidates)} '
          '(${formatDecimal(100 * s.selectedGateways / s.totalCandidates)}%)'
      : formatInt(s.selectedGateways);
  return [
    ReportParam('Pontos analisados', formatInt(s.totalPoints)),
    ReportParam('Pontos atendidos', formatInt(s.coveredPoints)),
    ReportParam('Pontos sem cobertura', formatInt(s.uncoveredPoints)),
    ReportParam('Candidatos avaliados', formatInt(s.totalCandidates)),
    ReportParam('Gateways selecionados', used),
    ReportParam('Média de pontos por gateway', perGateway),
    ReportParam('Alcance do gateway', formatRange(s.gatewayRangeM)),
  ];
}

/// Um número da ficha "Dados do cálculo" (rótulo, valor e observação).
class DataStat {
  const DataStat(this.label, this.value, [this.caption]);

  final String label;
  final String value;
  final String? caption;
}

List<DataStat> dataStats(ReportSummary s) {
  final share = s.totalCandidates > 0
      ? '${formatDecimal(100 * s.selectedGateways / s.totalCandidates)}% dos '
          'candidatos'
      : null;
  return [
    DataStat('Pontos analisados', formatInt(s.totalPoints)),
    DataStat('Candidatos avaliados', formatInt(s.totalCandidates)),
    DataStat('Pontos atendidos', formatInt(s.coveredPoints)),
    DataStat('Sem cobertura', formatInt(s.uncoveredPoints)),
    DataStat('Gateways selecionados', formatInt(s.selectedGateways), share),
    DataStat(
        'Média por gateway',
        s.selectedGateways > 0
            ? formatDecimal(s.coveredPoints / s.selectedGateways)
            : '-',
        'pontos atendidos'),
    DataStat('Alcance do gateway', formatRange(s.gatewayRangeM)),
  ];
}
