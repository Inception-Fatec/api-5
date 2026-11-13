// #TG-92: escolher no mapa quem é candidato e quem é ponto a cobrir.

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

PointsMapController _controller() => PointsMapController(
      nomeProjeto: 'Teste',
      distCode: '391',
      distribuidoraLabel: 'EDP SP',
      municipios: [IbgeService.municipioPorCodigo('3549904')],
    );

void main() {
  test('padrão: consumidores são pontos, transformadores são candidatos', () {
    final c = _controller();
    addTearDown(c.dispose);
    expect(c.coverageLayers, ['ucbt', 'ucmt_pj', 'ucat_pj']);
    expect(c.candidateLayers, ['untrmt', 'untrat']);
  });

  // CT2: o payload de /simulation/run leva os dois campos
  test('filter_params leva coverage_layers e candidate_layers', () {
    final c = _controller();
    addTearDown(c.dispose);
    c.setCoverageLayers(['ucbt']);
    c.setCandidateLayers(['ucmt_pj', 'untrmt']);

    final fp = c.filterParams;
    expect(fp['coverage_layers'], ['ucbt']);
    expect(fp['candidate_layers'], ['untrmt', 'ucmt_pj']);
    expect(c.filtros.coverageLayers, ['ucbt']);
  });

  test('não deixa um papel sem nenhuma camada', () {
    final c = _controller();
    addTearDown(c.dispose);
    c.setCandidateLayers([]);
    c.setCoverageLayers(['camada_que_nao_existe']);
    expect(c.candidateLayers, ['untrmt', 'untrat']);
    expect(c.coverageLayers, ['ucbt', 'ucmt_pj', 'ucat_pj']);
  });

  // CT1: trocar papéis → a cor e o formato do marcador mudam
  test('candidato roxo, rede azul, ponto na cor da tensão', () {
    expect(PointMarkersLayer.corDe(CategoriaPonto.candidato, 'BAIXO'),
        MapStyles.corCandidato);
    expect(PointMarkersLayer.corDe(CategoriaPonto.rede, 'ALTO'),
        MapStyles.corRede);
    expect(PointMarkersLayer.corDe(CategoriaPonto.ponto, 'ALTO'),
        MapStyles.corTensaoAlta);
    expect(PointMarkersLayer.corDe(CategoriaPonto.ponto, 'MEDIO'),
        MapStyles.corTensaoMedia);
    expect(PointMarkersLayer.corDe(CategoriaPonto.ponto, 'BAIXO'),
        MapStyles.corTensaoBaixa);
  });

  test('cores sólidas, sem transparência', () {
    for (final c in [
      MapStyles.corCandidato,
      MapStyles.corRede,
      MapStyles.corTensaoAlta,
      MapStyles.corTensaoMedia,
      MapStyles.corTensaoBaixa,
    ]) {
      expect(c.alpha, 255);
    }
  });


  test('TG-91: permite pontos CSV como cobertura e candidatos', () {
    final c = _controller();
    addTearDown(c.dispose);

    // O padrão continua sem os pontos externos.
    expect(c.coverageLayers, [
      'ucbt',
      'ucmt_pj',
      'ucat_pj',
    ]);
    expect(c.candidateLayers, ['untrmt', 'untrat']);

    // Seleciona apenas a camada externa.
    c.setCoverageLayers(['external_points']);
    c.setCandidateLayers(['external_points']);

    expect(c.coverageLayers, ['external_points']);
    expect(c.candidateLayers, ['external_points']);

    // Confirma os campos enviados para o projeto/motor.
    final params = c.filterParams;

    expect(
      params['coverage_layers'],
      ['external_points'],
    );

    expect(
      params['candidate_layers'],
      ['external_points'],
    );
  });

}
