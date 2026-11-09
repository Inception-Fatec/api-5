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
  test('nada vem escolhido: distribuidora e cidades só depois da escolha (#TG-147)', () async {
    final c = NewProjectDialogController(
      distribuidorasService: _DistribuidorasFalsas(
          const [Distribuidora(codigo: '380', nome: 'EDP Espírito Santo')]),
      ibgeService: _IbgeFalso({'380': [_vitoria]}),
    );
    await c.carregar();

    expect(c.carregando, isFalse);
    expect(c.distCode, isNull);
    expect(c.cidadesDisponiveis, isNull);
    expect(c.confirmar('Teste ES'), isNull);
    expect(c.erro, 'Escolhe a distribuidora.');

    await c.escolherDistribuidora('380');
    expect(c.distribuidoraLabel, 'EDP Espírito Santo (380)');
    expect(c.cidadesDisponiveis, [_vitoria]);
    expect(c.cidadesSelecionadas, isEmpty);
    expect(c.confirmar('Teste ES'), isNull);
    expect(c.erro, 'Escolhe ao menos uma cidade.');

    c.marcarCidade(_vitoria, marcada: true);

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
    await c.escolherDistribuidora('391');
    c.marcarCidade(_sjc, marcada: true);
    expect(c.cidadesSelecionadas, {_sjc});

    await c.escolherDistribuidora('380');
    expect(c.distCode, '380');
    expect(c.cidadesDisponiveis, [_vitoria]);
    expect(c.cidadesSelecionadas, isEmpty);
  });

  test('busca filtra as cidades pelo nome, sem acento e maiúsculas', () async {
    const serra = Municipio(codigoIbge: 3205002, nome: 'Serra', uf: 'ES');
    final c = NewProjectDialogController(
      distribuidorasService: _DistribuidorasFalsas(
          const [Distribuidora(codigo: '380', nome: 'EDP Espírito Santo')]),
      ibgeService: _IbgeFalso({'380': [serra, _vitoria]}),
    );
    await c.carregar();
    await c.escolherDistribuidora('380');

    c.buscar('VITO');
    expect(c.cidadesFiltradas, [_vitoria]);
    c.buscar('');
    expect(c.cidadesFiltradas, [serra, _vitoria]);
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
