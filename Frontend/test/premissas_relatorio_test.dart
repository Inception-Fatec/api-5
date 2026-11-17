// #TG-83: premissas do cálculo no relatório e texto do relevo conforme o
// que o motor realmente usou.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_about_section.dart';

Map<String, dynamic> _resumo(Map<String, dynamic> extra) => {
      'total_consumers': 3849,
      'covered_consumers': 3849,
      'uncovered_consumers': 0,
      'total_candidates': 4235,
      'selected_gateways': 22,
      'coverage_percentage': 100.0,
      'gateway_range_m': 19313,
      ...extra,
    };

const _comRelevo = {
  'gateway_profile': 'Tecsys',
  'frequency_mhz': 915.0,
  'tx_power_dbm': 21.0,
  'sensitivity_dbm': -120.0,
  'antenna_gains_db': 0.0,
  'extra_loss_db': 0.0,
  'gateway_height_m': 6.0,
  'sensor_height_m': 5.0,
  'bdgd_heights': false,
  'elevation_used': true,
  'elevation_source': 'COP30',
  'terrain_source': 'Copernicus GLO-30:mosaico 4 tiles',
};

CoverageReport _relatorio(Map<String, dynamic> extra) =>
    CoverageReport.fromJson({
      'summary': _resumo(extra),
      'gateways': [
        {
          'order': 1,
          'id': 'T1',
          'latitude': -23.1,
          'longitude': -45.7,
          'new_consumers_covered': 3849,
          'cumulative_consumers_covered': 3849,
          'cumulative_coverage_percentage': 100.0,
        }
      ],
      'points': {},
    });

void main() {
  group('leitura das premissas', () {
    test('cálculo atual: perfil, RF, alturas e relevo COP30', () {
      final s = ReportSummary.fromJson(_resumo(_comRelevo));
      final linhas = {for (final r in assumptionRows(s)) r.label: r.value};
      expect(linhas['Perfil de gateway'], 'Tecsys');
      expect(linhas['Frequência'], '915 MHz');
      expect(linhas['Potência de transmissão'], '21 dBm');
      expect(linhas['Sensibilidade de recepção'], '-120 dBm');
      expect(linhas['Perda adicional (vegetação, construções)'], '0 dB');
      expect(linhas['Alturas'], 'gateway 6 m · sensor 5 m');
      expect(linhas['Relevo'], 'Copernicus GLO-30 (30 m)');
      expect(linhas['Alcance do gateway'], '19,3 km');
    });

    test(
        'cálculo antigo (só terrain_source): deduz o relevo e omite o que falta',
        () {
      final s = ReportSummary.fromJson(
          _resumo({'terrain_source': 'Copernicus GLO-30:tile S24W046'}));
      final linhas = {for (final r in assumptionRows(s)) r.label: r.value};
      expect(s.assumptions.elevationUsed, isTrue);
      expect(linhas['Relevo'], 'Copernicus GLO-30 (30 m)');
      expect(linhas['Perfil de gateway'], 'Configuração padrão do motor');
      expect(linhas.containsKey('Frequência'), isFalse);
    });

    test('sem nenhuma informação de relevo: "Não informado", sem alerta', () {
      final s = ReportSummary.fromJson(_resumo({}));
      expect(s.assumptions.elevationUsed, isNull);
      expect(s.assumptions.semRelevo, isFalse);
      expect({for (final r in assumptionRows(s)) r.label: r.value}['Relevo'],
          'Não informado');
    });

    test('alturas da BDGD aparecem como tal', () {
      final s = ReportSummary.fromJson(_resumo({'bdgd_heights': true}));
      expect({for (final r in assumptionRows(s)) r.label: r.value}['Alturas'],
          'Pelo tipo de estrutura da BDGD');
    });
  });

  group('texto do relevo (CT2, CT3, CT4)', () {
    test('com relevo: frase e legenda dizem "relevo considerado", sem alerta',
        () {
      final r = _relatorio(_comRelevo);
      final textos = buildInsights(r).map((i) => i.text).join(' ');
      expect(textos, contains('relevo considerado'));
      expect(textos, isNot(contains(alertaSemRelevo)));
      expect(legendaAreaAtendida(r.summary.assumptions),
          'Área com cobertura (relevo considerado)');
    });

    test('sem relevo: nenhum "relevo considerado", alerta presente', () {
      final r = _relatorio({
        ...{..._comRelevo},
        'elevation_used': false,
        'elevation_source': 'plano',
        'terrain_source': 'plano'
      });
      final insights = buildInsights(r);
      final textos = insights.map((i) => i.text).join(' ');
      expect(textos, isNot(contains('relevo considerado')));
      expect(textos, contains('sem relevo: terreno plano'));
      expect(
          insights.any((i) =>
              i.kind == InsightKind.warning && i.text == alertaSemRelevo),
          isTrue);
      expect(legendaAreaAtendida(r.summary.assumptions),
          isNot(contains('relevo considerado')));
      expect(
          {
            for (final p in assumptionRows(r.summary)) p.label: p.value
          }['Relevo'],
          'Não usado (terreno plano)');
    });

    test('cálculo antigo sem informação: não afirma nada sobre o relevo', () {
      final r = _relatorio({});
      final textos = buildInsights(r).map((i) => i.text).join(' ');
      expect(textos, isNot(contains('relevo')));
      expect(legendaAreaAtendida(r.summary.assumptions), 'Área com cobertura');
    });
  });

  group('seção na tela', () {
    Future<void> montar(WidgetTester tester, Map<String, dynamic> extra) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportAssumptionsSection(
                  summary: ReportSummary.fromJson(_resumo(extra))),
            ),
          ),
        ));

    testWidgets('mostra as premissas e não mostra alerta com relevo',
        (tester) async {
      await montar(tester, _comRelevo);
      expect(find.text('Premissas do cálculo'), findsOneWidget);
      expect(find.text('Tecsys'), findsOneWidget);
      expect(find.text('Copernicus GLO-30 (30 m)'), findsOneWidget);
      expect(find.byKey(const Key('alerta-sem-relevo')), findsNothing);
    });

    testWidgets('CT2: sem relevo, o alerta aparece', (tester) async {
      await montar(tester, {
        ..._comRelevo,
        'elevation_used': false,
        'elevation_source': 'plano'
      });
      expect(find.byKey(const Key('alerta-sem-relevo')), findsOneWidget);
      expect(find.text(alertaSemRelevo), findsOneWidget);
    });
  });
}
