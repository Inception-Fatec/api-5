// #TG-146: área desenhada como polígono livre (vértices), no lugar do
// retângulo.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/state/desenho_poligono.dart';

void main() {
  // Triângulo em volta do centro de Caçapava.
  final triangulo = SelectedArea(const [
    LatLng(-23.08, -45.72),
    LatLng(-23.08, -45.68),
    LatLng(-23.12, -45.70),
  ]);

  // "L" de 6 vértices: quadrado 0..2 x 0..2 sem o quadrante de cima à direita.
  final l = SelectedArea(const [
    LatLng(0, 0),
    LatLng(0, 2),
    LatLng(1, 2),
    LatLng(1, 1),
    LatLng(2, 1),
    LatLng(2, 0),
  ]);

  group('SelectedArea', () {
    test('CT1: ponto dentro do triângulo conta, fora do triângulo não', () {
      expect(triangulo.contains(const LatLng(-23.09, -45.70)), isTrue);
      // Dentro do retângulo envolvente, mas fora do triângulo.
      expect(triangulo.contains(const LatLng(-23.115, -45.715)), isFalse);
    });

    test('CT2: ponto no "buraco" do L fica fora', () {
      expect(l.contains(const LatLng(0.5, 0.5)), isTrue);
      expect(l.contains(const LatLng(1.5, 0.5)), isTrue);
      expect(l.contains(const LatLng(0.5, 1.5)), isTrue);
      expect(l.contains(const LatLng(1.5, 1.5)), isFalse); // buraco
    });

    test(
        'CT3: uma área vira Polygon, duas viram MultiPolygon de anéis fechados',
        () {
      final um = SelectedArea.toGeoJson([triangulo])!;
      expect(um['type'], 'Polygon');
      final anel = (um['coordinates'] as List).first as List;
      expect(anel.length, 4); // 3 vértices + o primeiro repetido
      expect(anel.first, anel.last);
      expect(anel.first, [-45.72, -23.08]); // [lon, lat]

      final dois = SelectedArea.toGeoJson([triangulo, l])!;
      expect(dois['type'], 'MultiPolygon');
      expect((dois['coordinates'] as List).length, 2);
      expect(SelectedArea.toGeoJson([]), isNull);
    });

    test('CT5: gravata borboleta é detectada', () {
      final gravata = SelectedArea(const [
        LatLng(0, 0),
        LatLng(1, 1),
        LatLng(1, 0),
        LatLng(0, 1),
      ]);
      expect(gravata.seCruza, isTrue);
      expect(l.seCruza, isFalse);
      expect(triangulo.seCruza, isFalse);
    });

    test('CT7: retângulo salvo em projeto antigo volta com os mesmos 4 cantos',
        () {
      // Formato que o app gravava antes: 5 pontos, o último repete o primeiro.
      final antigo = {
        'type': 'Polygon',
        'coordinates': [
          [
            [-45.9, -23.1],
            [-45.8, -23.1],
            [-45.8, -23.2],
            [-45.9, -23.2],
            [-45.9, -23.1],
          ]
        ],
      };
      final areas = SelectedArea.fromGeoJson(antigo);
      expect(areas, [
        SelectedArea.retangulo(
            north: -23.1, south: -23.2, west: -45.9, east: -45.8)
      ]);
      expect(areas.single.vertices.length, 4);
    });

    test('polígono salvo volta com os mesmos vértices', () {
      final volta =
          SelectedArea.fromGeoJson(SelectedArea.toGeoJson([l, triangulo]));
      expect(volta, [l, triangulo]);
    });

    test('área em km²: quadrado de ~1 km de lado', () {
      // 0,009° de latitude ≈ 1 km; no equador a longitude tem a mesma escala.
      final q =
          SelectedArea.retangulo(north: 0.009, south: 0, west: 0, east: 0.009);
      expect(q.areaKm2, closeTo(1.0, 0.01));
      expect(l.areaKm2, closeTo(3 * 111.2 * 111.2, 3 * 111.2 * 111.2 * 0.01));
    });
  });

  group('DesenhoPoligono', () {
    test('CT4: com 2 vértices não dá para concluir', () {
      final d = DesenhoPoligono();
      d.clicar(const LatLng(0, 0));
      d.clicar(const LatLng(0, 1));
      expect(d.podeConcluir, isFalse);
      expect(d.clicar(const LatLng(0, 1), duplo: true),
          CliqueDesenho.poucosVertices);
      expect(d.concluir(), isNull);
      expect(d.total, 2); // nada foi perdido
    });

    test('CT6: desfazer 2 vezes remove os 2 últimos vértices', () {
      final d = DesenhoPoligono();
      for (final p in const [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ]) {
        d.clicar(p);
      }
      d.desfazer();
      d.desfazer();
      expect(d.vertices, const [LatLng(0, 0), LatLng(0, 1)]);
    });

    test('CT5: vértice que faria os lados se cruzarem é recusado', () {
      final d = DesenhoPoligono();
      d.clicar(const LatLng(0, 0));
      d.clicar(const LatLng(1, 1));
      d.clicar(const LatLng(1, 0));
      // Lado (1,0)->(0,2) cruza o lado (0,0)->(1,1).
      expect(d.clicar(const LatLng(0, 2)), CliqueDesenho.cruzaria);
      expect(d.total, 3);
    });

    test('fechar no primeiro vértice ou com duplo clique conclui a área', () {
      final d = DesenhoPoligono();
      d.clicar(const LatLng(0, 0));
      d.clicar(const LatLng(0, 1));
      d.clicar(const LatLng(1, 1));
      expect(
          d.clicar(const LatLng(0, 0), noPrimeiro: true), CliqueDesenho.fechou);
      final area = d.concluir();
      expect(area?.vertices.length, 3);
      expect(d.vazio, isTrue);
    });

    test('cancelar limpa o desenho', () {
      final d = DesenhoPoligono();
      d.clicar(const LatLng(0, 0));
      d.cursor = const LatLng(1, 1);
      d.limpar();
      expect(d.vazio, isTrue);
      expect(d.cursor, isNull);
    });
  });
}
