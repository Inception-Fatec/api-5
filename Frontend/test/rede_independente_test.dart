// #TG-151: rede independente (só os pontos do CSV) e duração "<1 s".

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/etl_geodados/models/etl_carga.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Cidades da distribuidora com a origem dos dados, sem chamar o backend.
class _OrigemFalsa extends DistribuidorasService {
  _OrigemFalsa(this.cidades);

  final List<MunicipioComDados> cidades;

  @override
  Future<List<MunicipioComDados>> municipios(String distCode) async => cidades;
}

PointsMapController _controller(List<MunicipioComDados> cidades,
        {String mun = '3508504', int? projetoId}) =>
    PointsMapController(
      nomeProjeto: 'Teste',
      distCode: '999',
      distribuidoraLabel: 'Rede Teste',
      municipios: [IbgeService.municipioPorCodigo(mun)],
      projetoId: projetoId,
      distribuidorasService: _OrigemFalsa(cidades),
    );

const _csv = ['external_points'];

void main() {
  test('CT4: cidade sem BDGD e com CSV abre como rede independente', () async {
    final c = _controller(const [
      MunicipioComDados(codigo: 3508504, temRede: false, temCsv: true),
    ]);
    addTearDown(c.dispose);
    await c.carregarOrigemDosDados();
    expect(c.redeIndependente, isTrue);
    expect(c.coverageLayers, _csv);
    expect(c.candidateLayers, _csv);
    expect(c.soPlanilha, isTrue);
  });

  test('cidade com BDGD continua no padrão e oferece o atalho se houver CSV',
      () async {
    final c = _controller(const [
      MunicipioComDados(codigo: 3508504, temRede: true, temCsv: true),
    ]);
    addTearDown(c.dispose);
    await c.carregarOrigemDosDados();
    expect(c.redeIndependente, isFalse);
    expect(c.coverageLayers, ['ucbt', 'ucmt_pj', 'ucat_pj']);
    expect(c.temPontosCsv, isTrue, reason: 'o atalho aparece');
    expect(c.soPlanilha, isFalse);

    // CT5: o atalho troca os dois seletores para só o CSV.
    c.usarSoPlanilha();
    expect(c.coverageLayers, _csv);
    expect(c.candidateLayers, _csv);
    expect(c.soPlanilha, isTrue);
  });

  test('cidade sem pontos de CSV não mostra o atalho', () async {
    final c = _controller(const [
      MunicipioComDados(codigo: 3508504, temRede: true, temCsv: false),
    ]);
    addTearDown(c.dispose);
    await c.carregarOrigemDosDados();
    expect(c.temPontosCsv, isFalse);
  });

  test('projeto aberto para recalcular mantém as camadas salvas', () async {
    final c = _controller(const [
      MunicipioComDados(codigo: 3508504, temRede: false, temCsv: true),
    ], projetoId: 5);
    addTearDown(c.dispose);
    await c.carregarOrigemDosDados();
    expect(c.redeIndependente, isFalse);
    expect(c.coverageLayers, ['ucbt', 'ucmt_pj', 'ucat_pj']);
  });

  test('CT7: importação com menos de 1 segundo mostra "<1 s"', () {
    final c = EtlCarga.fromJson({
      'id': 1,
      'status': 'SUCCESS',
      'originalFilename': 'pontos.csv',
      'startedAt': '2026-11-16T20:00:00.100Z',
      'finishedAt': '2026-11-16T20:00:00.400Z',
      'summary': {
        'tipo': 'csv',
        'total': 1,
        'importadas': 1,
        'jaExistentes': 0,
        'rejeitadas': 0,
        'rejeicoes': []
      },
    });
    expect(c.duracao, '<1 s');
  });
}
