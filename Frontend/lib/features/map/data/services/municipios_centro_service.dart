import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/core/network/api_client.dart';

/// Centro de cada cidade com dados de uma distribuidora, vindo do backend
/// (GET /distribuidoras/{dist}/municipios — centro do envelope dos
/// transformadores da cidade). Guarda em cache por distribuidora.
class MunicipiosCentroService {
  static final Map<String, Map<int, LatLng>> _cache = {};

  Future<Map<int, LatLng>> centros(String distCode) async {
    final emCache = _cache[distCode];
    if (emCache != null) return emCache;

    final data = await ApiClient.instance
        .getJson('/distribuidoras/${Uri.encodeComponent(distCode)}/municipios');
    final lista = (data as List?) ?? const [];

    final centros = <int, LatLng>{};
    for (final item in lista) {
      if (item is! Map) continue;
      final codigo = int.tryParse('${item['ibge_code']}');
      final lat = (item['latitude'] as num?)?.toDouble();
      final lon = (item['longitude'] as num?)?.toDouble();
      if (codigo == null || lat == null || lon == null) continue;
      centros[codigo] = LatLng(lat, lon);
    }
    _cache[distCode] = centros;
    return centros;
  }
}
