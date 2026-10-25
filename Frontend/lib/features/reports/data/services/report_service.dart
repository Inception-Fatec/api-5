import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';

/// Fonte do relatório de cobertura de um projeto. A tela só conhece
/// esta interface.
abstract class ReportService {
  /// Se true, o relatório só existe depois que o projeto termina o
  /// cálculo (status SUCESSO).
  bool get requiresCompletedProject;

  /// Status atual do projeto no servidor, ou null se esta fonte não tem
  /// como saber (aí vale o status que a lista já trazia). Necessário
  /// porque o motor grava SUCESSO/FALHA direto no banco e a lista de
  /// projetos do app pode estar desatualizada.
  Future<String?> statusAtual(int projectId);

  Future<CoverageReport> carregar(int projectId);
}

/// Lê o relatório que o motor salvou no banco (`project_coverage`).
class ApiReportService implements ReportService {
  ApiReportService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /api/v1/reports/projects/{id}/coverage` (a base `/api/v1` vem
  /// do ApiConfig).
  static String path(int projectId) => '/reports/projects/$projectId/coverage';

  @override
  bool get requiresCompletedProject => true;

  @override
  Future<String?> statusAtual(int projectId) async {
    final data = await _client.getJson('/projects/$projectId');
    return data is Map ? data['status'] as String? : null;
  }

  @override
  Future<CoverageReport> carregar(int projectId) async {
    final bytes = await _client.getBytes(path(projectId));
    // Parse fora da thread da UI: o JSON pode ter centenas de milhares
    // de pontos (na web o compute roda na própria thread, sem isolate).
    return compute(parseCoverageReportBytes, bytes);
  }
}
