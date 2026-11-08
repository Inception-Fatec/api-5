import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';

class _DistribuidorasFalsas extends DistribuidorasService {
  _DistribuidorasFalsas(this.lista);

  final List<Distribuidora> lista;

  @override
  Future<List<Distribuidora>> listar() async {
    registrarDistribuidoras({for (final d in lista) d.codigo: d.nome});
    return lista;
  }
}

class _IbgeFalso extends IbgeService {
  _IbgeFalso(this.cidades);

  final Map<String, List<Municipio>> cidades;

  @override
  Future<List<Municipio>> buscarCidadesComDados(String distCode) async =>
      cidades[distCode] ?? const [];
}

const _sjc = Municipio(codigoIbge: 3549904, nome: 'São José dos Campos', uf: 'SP');
const _vitoria = Municipio(codigoIbge: 3205309, nome: 'Vitória', uf: 'ES');

void main() {
  test('usa a distribuidora e as cidades que vieram do banco', () async {
    final c = NewProjectDialogController(
      distribuidorasService: _DistribuidorasFalsas(
          const [Distribuidora(codigo: '380', nome: 'EDP Espírito Santo')]),
      ibgeService: _IbgeFalso({'380': [_vitoria]}),
    );
    await c.carregar();

    expect(c.distCode, '380');
    expect(c.distribuidoraLabel, 'EDP Espírito Santo (380)');
    expect(c.cidadesDisponiveis, [_vitoria]);
    expect(c.cidadesSelecionadas, {_vitoria});

    final r = c.confirmar('Teste ES');
    expect(r?.distCode, '380');
    expect(r?.municipios, [_vitoria]);
  });

  test('trocar a distribuidora troca as cidades e desmarca as antigas', () async {
    final c = NewProjectDialogController(
      distribuidorasService: _DistribuidorasFalsas(const [
        Distribuidora(codigo: '391', nome: 'EDP São Paulo'),
        Distribuidora(codigo: '380', nome: 'EDP Espírito Santo'),
      ]),
      ibgeService: _IbgeFalso({'391': [_sjc], '380': [_vitoria]}),
    );
    await c.carregar();
    expect(c.cidadesSelecionadas, {_sjc});

    await c.escolherDistribuidora('380');
    expect(c.distCode, '380');
    expect(c.cidadesDisponiveis, [_vitoria]);
    expect(c.cidadesSelecionadas, {_vitoria});
  });

  test('sem distribuidora no banco avisa e não deixa confirmar', () async {
    final c = NewProjectDialogController(
      distribuidorasService: _DistribuidorasFalsas(const []),
      ibgeService: _IbgeFalso(const {}),
    );
    await c.carregar();

    expect(c.carregando, isFalse);
    expect(c.distCode, isNull);
    expect(c.erro, contains('Nenhuma distribuidora'));
    expect(c.confirmar('Projeto'), isNull);
  });

  test('distribuidora sem nome no banco usa o nome conhecido ou o código', () {
    registrarDistribuidoras({'999': ''});
    expect(nomeDistribuidora('391'), 'EDP São Paulo');
    expect(nomeDistribuidora('999'), '999');
  });
}
