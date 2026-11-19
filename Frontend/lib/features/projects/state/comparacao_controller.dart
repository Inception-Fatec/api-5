import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/data/services/report_service.dart';

/// Um cenário da comparação: o projeto e o relatório dele.
class CenarioComparado {
  CenarioComparado(this.projeto);

  final Project projeto;
  CoverageReport? relatorio;
  String? erro;

  bool get carregando => relatorio == null && erro == null;
}

/// Diferença de um cenário para a referência (o 1º projeto marcado).
class DeltaCenario {
  const DeltaCenario({required this.coberturaPp, required this.gateways});

  /// Em pontos percentuais: 80% → 85% = +5 p.p.
  final double coberturaPp;
  final int gateways;

  /// Mesmos números do relatório: cobertura % e "Gateways selecionados".
  factory DeltaCenario.entre(ReportSummary referencia, ReportSummary cenario) =>
      DeltaCenario(
        coberturaPp: cenario.coveragePercentage - referencia.coveragePercentage,
        gateways: cenario.selectedGateways - referencia.selectedGateways,
      );
}

/// Estado da tela "Comparar cenários": carrega o relatório de cada projeto
/// marcado (em paralelo) e calcula o Δ de cada um para a referência.
class ComparacaoController extends ChangeNotifier {
  ComparacaoController(List<Project> projetos, {ReportService? service})
      : cenarios = [for (final p in projetos) CenarioComparado(p)],
        _service = service ?? ApiReportService();

  final List<CenarioComparado> cenarios;
  final ReportService _service;
  bool _descartado = false;

  /// O 1º marcado: base de todos os Δ.
  CenarioComparado get referencia => cenarios.first;

  Future<void> carregar() =>
      Future.wait([for (final c in cenarios) _carregar(c)]);

  Future<void> recarregar(CenarioComparado c) {
    c.erro = null;
    notifyListeners();
    return _carregar(c);
  }

  Future<void> _carregar(CenarioComparado c) async {
    try {
      c.relatorio = await _service.carregar(c.projeto.id);
    } catch (_) {
      c.erro = 'Não foi possível carregar o relatório deste projeto.';
    }
    if (!_descartado) notifyListeners();
  }

  /// Δ para a referência; null na própria referência ou enquanto um dos
  /// dois relatórios não chegou.
  DeltaCenario? delta(CenarioComparado c) {
    final ref = referencia.relatorio;
    final rel = c.relatorio;
    if (identical(c, referencia) || ref == null || rel == null) return null;
    return DeltaCenario.entre(ref.summary, rel.summary);
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
