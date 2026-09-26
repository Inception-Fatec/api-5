import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../widgets/map/selected_area.dart';

class CitySearchResult {
  final String displayName;
  final double lat;
  final double lon;
  final SelectedArea area;

  const CitySearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.area,
  });
}

/// Busca de lugares por nome, usando a Nominatim (geocoding gratuito
/// do projeto OpenStreetMap — sem necessidade de chave de API).
///
/// Cada resultado já vem com um `boundingbox` (south/north/west/east)
/// pronto — pra cidades e municípios, geralmente é exatamente o
/// contorno administrativo do lugar, então dá pra usar direto como
/// [SelectedArea], sem precisar de nenhum desenho manual.
///
/// Política de uso da Nominatim exige um User-Agent identificável e no
/// máximo ~1 requisição por segundo — adequado pro uso esporádico de
/// busca de cidade aqui, não pra chamadas em massa.
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<CitySearchResult>> buscar(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '5',
      'addressdetails': '0',
      // Prioriza resultados no Brasil, já que o projeto é sobre
      // distribuidoras de energia brasileiras — não impede outros
      // países, só ordena melhor.
      'countrycodes': 'br',
    });

    final resposta = await http.get(
      uri,
      headers: {
        // Nominatim exige um User-Agent identificável (não pode ser o
        // default do http/Dart) — ajuste pro nome real do app/contato.
        'User-Agent': 'tecsys_app (contato@tecsysbrasil.com.br)',
      },
    ).timeout(const Duration(seconds: 10));

    if (resposta.statusCode != 200) return [];

    final lista = jsonDecode(resposta.body) as List;
    return lista.map((item) {
      final bbox = (item['boundingbox'] as List).map((v) => double.parse(v as String)).toList();
      // Nominatim retorna [south, north, west, east], nessa ordem.
      final south = bbox[0];
      final north = bbox[1];
      final west = bbox[2];
      final east = bbox[3];
      final lat = double.parse(item['lat'] as String);
      final lon = double.parse(item['lon'] as String);
      final nome = item['display_name'] as String;

      return CitySearchResult(
        displayName: nome,
        lat: lat,
        lon: lon,
        area: SelectedArea(
          south: south,
          north: north,
          west: west,
          east: east,
          diagonalKm: _diagonalAproximadaKm(south, north, west, east),
          label: nome.split(',').first, // só a parte principal do nome
        ),
      );
    }).toList();
  }

  double _diagonalAproximadaKm(double south, double north, double west, double east) {
    // Aproximação rápida (equiretangular) só pra exibir um número —
    // não precisa da precisão geodésica exata do Distance() do
    // latlong2 aqui, é só um rótulo informativo no histórico/badge.
    const kmPorGrauLat = 111.0;
    final latMedia = (south + north) / 2;
    final kmPorGrauLon = 111.0 * math.cos(latMedia * math.pi / 180).abs();
    final dLat = (north - south) * kmPorGrauLat;
    final dLon = (east - west) * kmPorGrauLon;
    return math.sqrt(dLat * dLat + dLon * dLon);
  }
}