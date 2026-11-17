// #TG-153: ajuda contextual ("?") nas telas e dicas nos campos técnicos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/core/ajuda/ajuda.dart';
import 'package:tecsys_app/core/ajuda/textos_ajuda.dart';
import 'package:tecsys_app/core/widgets/page_title.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_legend.dart';

Future<void> _montar(WidgetTester tester, Widget filho,
    {Size tamanho = const Size(1200, 900)}) async {
  await tester.binding.setSurfaceSize(tamanho);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: filho))));
}

void main() {
  test('todas as telas têm ajuda com objetivo e passo a passo', () {
    final telas = [
      TextosAjuda.login,
      TextosAjuda.trocaSenha,
      TextosAjuda.projetos,
      TextosAjuda.novoProjeto,
      TextosAjuda.mapa,
      TextosAjuda.relatorio,
      TextosAjuda.perfis,
      TextosAjuda.etl,
      TextosAjuda.usuarios,
    ];
    for (final t in telas) {
      expect(t.objetivo, isNotEmpty, reason: t.titulo);
      expect(t.passos, isNotEmpty, reason: t.titulo);
    }
  });

  test('a ajuda do mapa explica todos os filtros e a legenda inteira', () {
    final termos = [
      for (final s in TextosAjuda.mapa.secoes)
        for (final i in s.itens) i.termo,
    ];
    for (final filtro in [
      'Pontos a cobrir',
      'Candidatos a gateway',
      'Áreas',
      'Bairro',
      'Nível de tensão',
      'Conjunto',
      'Subestação',
      'Classe',
      'CNAE',
    ]) {
      expect(termos, contains(filtro));
    }
    for (final legenda in [
      'Ponto de alta tensão',
      'Ponto de média tensão',
      'Ponto de baixa tensão',
      'Candidato a gateway',
      'Rede elétrica',
      'Área desenhada',
      'até 9',
      '10 a 99',
      '100 a 999',
      '1 mil ou mais',
    ]) {
      expect(termos, contains(legenda));
    }
  });

  testWidgets(
      'CT1: o "?" do título abre o painel com objetivo, passos e seções',
      (tester) async {
    await _montar(
        tester,
        const PageTitle(
            title: 'Meus Projetos',
            countLabel: '3 projetos',
            fontSize: 24,
            ajuda: TextosAjuda.projetos));
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Passo a passo'), findsOneWidget);
    expect(find.text('Status do projeto'), findsOneWidget);
    expect(find.text(TextosAjuda.projetos.objetivo), findsOneWidget);
  });

  testWidgets(
      'CT3: no celular (400 px) a ajuda abre como folha, sem estourar a largura',
      (tester) async {
    await _montar(tester, AjudaBotao(ajuda: TextosAjuda.mapa),
        tamanho: const Size(400, 800));
    await tester.tap(find.byType(AjudaBotao));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Passo a passo'), findsOneWidget);
    // A ajuda do mapa é longa: rola até as seções de filtros e legenda.
    await tester.scrollUntilVisible(find.text('Filtros'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Filtros'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'sem overflow');
  });

  testWidgets('legenda do mapa: "o que é cada cor" abre a ajuda',
      (tester) async {
    var abriu = false;
    await _montar(tester, MapLegend(onAjuda: () => abriu = true));
    expect(find.text('o que é cada cor'), findsOneWidget);
    await tester.tap(find.byKey(const Key('legenda-ajuda')));
    expect(abriu, isTrue);
  });

  testWidgets('CT2: a dica do campo técnico mostra a explicação',
      (tester) async {
    await _montar(tester, const AjudaDica(TextosAjuda.campoSensibilidade));
    await tester.tap(find.byType(AjudaDica));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('MAIS NEGATIVO'), findsOneWidget);
  });
}
