// #TG-79: tela de perfis de gateway e seleção do perfil no novo projeto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile_service.dart';
import 'package:tecsys_app/features/gateway_profiles/ui/gateway_profiles_dialog.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';

const _padrao = GatewayProfile(
  id: 1,
  name: 'Tecsys',
  frequencyMhz: 915,
  txPowerDbm: 21,
  antennaGainDbi: 0,
  rxSensitivityDbm: -120,
  antennaHeightM: 6,
  sensorHeightM: 5,
  extraLossDb: 0,
  isDefault: true,
);

/// Serviço em memória: guarda os perfis criados/editados.
class _PerfisFalsos extends GatewayProfileService {
  _PerfisFalsos([List<GatewayProfile>? iniciais])
      : perfis = [...(iniciais ?? [_padrao])];

  final List<GatewayProfile> perfis;
  GatewayProfile? ultimoEnviado;

  @override
  Future<List<GatewayProfile>> listar() async => List.of(perfis);

  @override
  Future<GatewayProfile> criar(GatewayProfile perfil) async {
    ultimoEnviado = perfil;
    final novo = GatewayProfile.fromJson({...perfil.toJson(), 'id': perfis.length + 1});
    perfis.add(novo);
    return novo;
  }

  @override
  Future<GatewayProfile> editar(int id, GatewayProfile perfil) async {
    ultimoEnviado = perfil;
    final editado = GatewayProfile.fromJson({...perfil.toJson(), 'id': id});
    perfis[perfis.indexWhere((p) => p.id == id)] = editado;
    return editado;
  }
}

class _DistribuidorasFalsas extends DistribuidorasService {
  @override
  Future<List<Distribuidora>> listar() async =>
      const [Distribuidora(codigo: '391', nome: 'EDP São Paulo')];
}

class _IbgeFalso extends IbgeService {
  @override
  Future<List<Municipio>> buscarCidadesComDados(String distCode) async =>
      const [Municipio(codigoIbge: 3508504, nome: 'Caçapava', uf: 'SP')];
}

Future<void> _abrirTela(WidgetTester tester, _PerfisFalsos service) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => GatewayProfilesDialog.mostrar(context, service: service),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('validação dos campos', () {
    test('nome vazio, texto e fora da faixa têm mensagem própria', () {
      expect(CampoPerfil.nome.validar('  '), 'Informe o nome do perfil.');
      expect(CampoPerfil.frequencia.validar('abc'), contains('Use um número'));
      expect(CampoPerfil.frequencia.validar('0'), contains('entre 1 e 6000'));
      expect(CampoPerfil.sensibilidade.validar('10'), contains('entre -150 e -40'));
      expect(CampoPerfil.perda.validar('-1'), contains('entre 0 e 60'));
      expect(CampoPerfil.potencia.validar('14,5'), isNull, reason: 'aceita vírgula');
      expect(CampoPerfil.sensibilidade.validar('-120'), isNull);
    });

    test('orçamento de enlace desconta a perda adicional', () {
      expect(_padrao.orcamentoDb, 141);
      const urbano = GatewayProfile(
        name: 'Urbano', frequencyMhz: 915, txPowerDbm: 14, antennaGainDbi: 0,
        rxSensitivityDbm: -120, antennaHeightM: 6, sensorHeightM: 5, extraLossDb: 20);
      expect(urbano.orcamentoDb, 114);
    });
  });

  group('novo projeto', () {
    test('CT3: já vem com o perfil padrão selecionado e envia o id escolhido', () async {
      const outro = GatewayProfile(
        id: 2, name: 'Urbano', frequencyMhz: 915, txPowerDbm: 14, antennaGainDbi: 0,
        rxSensitivityDbm: -120, antennaHeightM: 6, sensorHeightM: 5, extraLossDb: 20);
      final c = NewProjectDialogController(
        distribuidorasService: _DistribuidorasFalsas(),
        ibgeService: _IbgeFalso(),
        perfisService: _PerfisFalsos([outro, _padrao]),
      );
      await c.carregarPerfis();
      expect(c.perfis.first.isDefault, isFalse, reason: 'a ordem vem do serviço');
      expect(c.perfilId, 1, reason: 'o padrão vem selecionado mesmo não sendo o 1º');

      await c.carregar();
      await c.escolherDistribuidora('391');
      c.marcarCidade(c.cidadesDisponiveis!.first, marcada: true);
      c.escolherPerfil(2);
      expect(c.confirmar('Teste')?.gatewayProfileId, 2);
    });

    test('perfil criado na tela de perfis volta selecionado', () async {
      final service = _PerfisFalsos();
      final c = NewProjectDialogController(
        distribuidorasService: _DistribuidorasFalsas(),
        ibgeService: _IbgeFalso(),
        perfisService: service,
      );
      await c.carregarPerfis();
      final novo = await service.criar(GatewayProfile.referenciaTecsys);
      await c.carregarPerfis(selecionar: novo.id);
      expect(c.perfilId, novo.id);
    });
  });

  group('tela de perfis', () {
    testWidgets('lista mostra o padrão sem opção de excluir', (tester) async {
      await _abrirTela(tester, _PerfisFalsos());
      expect(find.text('Perfis de gateway'), findsOneWidget);
      expect(find.text('Tecsys'), findsOneWidget);
      expect(find.text('Padrão'), findsOneWidget);
      final excluir = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline));
      expect(excluir.onPressed, isNull);
    });

    testWidgets('CT2: campo inválido mostra o erro no próprio campo', (tester) async {
      final service = _PerfisFalsos();
      await _abrirTela(tester, service);
      await tester.tap(find.byKey(const Key('novo-perfil')));
      await tester.pumpAndSettle();

      // nome vazio e sensibilidade positiva
      await tester.enterText(find.byKey(const Key('campo-sensibilidade')), '10');
      await tester.tap(find.byKey(const Key('salvar-perfil')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome do perfil.'), findsOneWidget);
      expect(find.textContaining('entre -150 e -40'), findsOneWidget);
      expect(service.ultimoEnviado, isNull, reason: 'não envia com erro');
    });

    testWidgets('CT1: criar perfil e vê-lo na lista', (tester) async {
      final service = _PerfisFalsos();
      await _abrirTela(tester, service);
      await tester.tap(find.byKey(const Key('novo-perfil')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campo-nome')), 'Urbano 14 dBm');
      await tester.enterText(find.byKey(const Key('campo-potencia')), '14');
      await tester.enterText(find.byKey(const Key('campo-perda')), '20');
      await tester.tap(find.byKey(const Key('salvar-perfil')));
      await tester.pumpAndSettle();

      expect(service.ultimoEnviado?.txPowerDbm, 14);
      expect(service.ultimoEnviado?.extraLossDb, 20);
      expect(service.ultimoEnviado?.rxSensitivityDbm, -120, reason: 'veio preenchido');
      expect(find.text('Urbano 14 dBm'), findsOneWidget);
    });

    testWidgets('padrão não tem lápis: Duplicar abre um perfil novo com os valores dele', (tester) async {
      final service = _PerfisFalsos();
      await _abrirTela(tester, service);
      expect(find.widgetWithIcon(IconButton, Icons.edit_outlined), findsNothing);

      await tester.tap(find.byKey(const Key('duplicar-padrao')));
      await tester.pumpAndSettle();
      expect(find.text('Novo perfil'), findsOneWidget);
      expect(find.text('Cópia de Tecsys'), findsOneWidget);

      await tester.tap(find.byKey(const Key('salvar-perfil')));
      await tester.pumpAndSettle();
      expect(service.perfis.length, 2, reason: 'criou outro, não alterou o padrão');
      expect(service.perfis.first.name, 'Tecsys');
    });
  });
}
