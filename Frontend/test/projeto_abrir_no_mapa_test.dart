// #TG-85/#TG-86: abrir projeto salvo no mapa com a área e os filtros da
// última versão do histórico.

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

void main() {
  final area = SelectedArea.retangulo(
      north: -23.1, south: -23.2, west: -45.9, east: -45.8);

  Map<String, dynamic> versaoJson({required Map<String, dynamic>? polygon}) => {
        'id': 2,
        'created_at': '09/11/2026 09:30:00',
        'gateway_profile': null,
        'filter_params': {
          'mun_codes': ['3549904'],
          'target_layers': ['baixo'],
          'clas_sub': ['CO1'],
          'bairro_names': ['CENTRO'],
        },
        'polygon': polygon,
      };

  test('versão lê data no formato do backend, filtros e área', () {
    final v = ProjectVersion.fromJson(
        versaoJson(polygon: SelectedArea.toGeoJson([area])));

    expect(v.criadoEm, DateTime(2026, 11, 9, 9, 30));
    expect(v.munCodes, ['3549904']);
    expect(v.bairroNames, ['CENTRO']);
    expect(v.gatewayProfile, isNull);
    expect(SelectedArea.fromGeoJson(v.polygon), [area]);
  });

  test('MultiPolygon volta como uma área por polígono; sem área, lista vazia',
      () {
    final outra = SelectedArea.retangulo(
        north: -23.0, south: -23.05, west: -45.7, east: -45.6);
    expect(SelectedArea.fromGeoJson(SelectedArea.toGeoJson([area, outra])),
        [area, outra]);
    expect(SelectedArea.fromGeoJson(null), isEmpty);
  });

  test('CT1: abrir projeto carrega a mesma área e os mesmos filtros', () {
    final v = ProjectVersion.fromJson(
        versaoJson(polygon: SelectedArea.toGeoJson([area])));
    final c = PointsMapController(
      nomeProjeto: 'SJC centro',
      distCode: '391',
      distribuidoraLabel: 'EDP SP',
      municipios: [IbgeService.municipioPorCodigo('3549904')],
      projetoId: 5,
      versaoInicial: v,
    );
    addTearDown(c.dispose);

    expect(c.editando, isTrue);
    expect(c.areas.areas, [area]);
    expect(c.targetLayers, ['baixo']);
    expect(c.clasSub, ['CO1 — Comercial']);
    expect(c.bairroNames, ['CENTRO']);
    expect(c.munCodes, ['3549904']);

    // salva de volta igual: mesmos filtros e a mesma área no recálculo
    final fp = c.filterParams;
    expect(fp['clas_sub'], ['CO1']);
    expect(fp['bairro_names'], ['CENTRO']);
    expect(
        SelectedArea.fromGeoJson(
            fp['polygon_geojson'] as Map<String, dynamic>?),
        [area]);
  });
}
