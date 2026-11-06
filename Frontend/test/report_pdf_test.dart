import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/export/report_pdf.dart';

void main() {
  test('pdfSafe troca só o que a Helvetica não tem e mantém os acentos', () {
    expect(pdfSafe('Relatório — Página 1 • área…'),
        'Relatório - Página 1 - área...');
  });

  test('gera o PDF com títulos acentuados e um gateway', () async {
    final report = CoverageReport.fromJson({
      'summary': {
        'total_points': 10,
        'total_candidates': 3,
        'selected_gateways': 1,
        'covered_points': 10,
        'uncovered_points': 0,
        'coverage_percentage': 100.0,
        'gateway_range_m': 4000,
      },
      'gateways': [
        {
          'order': 1,
          'id': 'T1',
          'type': 'UNTRMT',
          'latitude': -23.2,
          'longitude': -45.9,
          'new_points_covered': 10,
          'cumulative_points_covered': 10,
          'cumulative_coverage_percentage': 100.0,
        }
      ],
    });
    final bytes = await buildReportPdf(
        projectName: 'Teste', distribuidora: 'EDP São Paulo', date: '05/11/2026', report: report);
    expect(bytes.length, greaterThan(1000));
  });
}
