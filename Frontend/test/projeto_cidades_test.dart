// #TG-148: card e relatório mostram as cidades do projeto.

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';

void main() {
  test('projeto lê mun_codes do último cálculo; sem cálculo fica vazio', () {
    final p = Project.fromJson({
      'id': 5,
      'name': 'teste novo etl',
      'dist_code': '380',
      'mun_codes': ['3205309', '3200607', ''],
    });
    expect(p.munCodes, ['3205309', '3200607']);

    final novo = Project.fromJson({'id': 6, 'name': 'sem cálculo', 'dist_code': '380'});
    expect(novo.munCodes, isEmpty);
  });

  test('sem a lista do IBGE carregada, as cidades aparecem pelo código', () {
    expect(IbgeService.rotulosMunicipios(['3205309', '3200607']), '3200607, 3205309');
  });

  test('relatório lê os filtros (filter_params) devolvidos pelo backend', () {
    final f = ReportFilters.fromReportJson({
      'filter_params': {
        'mun_codes': ['3200607', '3205309'],
        'dist_codes': ['380'],
        'bairro_names': ['Centro'],
        'target_layers': ['all'],
        'polygon_geojson': null,
      },
    });
    expect(f, isNotNull);
    expect(f!.munCodes, ['3200607', '3205309']);
    expect(f.bairroNames, ['Centro']);
    expect(f.hasPolygon, isFalse);
  });
}
