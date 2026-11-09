import 'package:latlong2/latlong.dart';

/// Regiões que já têm dados carregados hoje (São José dos Campos e
/// Caçapava) e os centros usados para posicionar o mapa.
class MapRegions {
  MapRegions._();

  static const codigoSaoJoseDosCampos = 3549904;
  static const codigoCacapava = 3508504;

  static const centroSaoJoseDosCampos = LatLng(-23.1896, -45.8841);
  static const centroCacapava = LatLng(-23.0996, -45.7075);
  static const centroEntreAsDuas = LatLng(-23.1446, -45.7958);

  /// Zoom ao abrir o mapa ou ao saltar para uma cidade.
  static const zoomInicial = 18.0;

  /// Zoom ao centralizar no primeiro ponto de um filtro.
  static const zoomFiltro = 17.0;

  /// Centro fixo de uma cidade conhecida, ou null para as demais.
  static LatLng? centroFixoDe(int codigoIbge) {
    if (codigoIbge == codigoSaoJoseDosCampos) return centroSaoJoseDosCampos;
    if (codigoIbge == codigoCacapava) return centroCacapava;
    return null;
  }

  /// Centro inicial do mapa para as cidades escolhidas: entre as duas
  /// quando ambas estão presentes, Caçapava sozinha, ou SJC por padrão.
  static LatLng centroInicial(Iterable<int> codigosIbge) {
    final codigos = codigosIbge.toSet();
    final temSjc = codigos.contains(codigoSaoJoseDosCampos);
    final temCacapava = codigos.contains(codigoCacapava);

    if (temSjc && temCacapava) return centroEntreAsDuas;
    if (temCacapava) return centroCacapava;
    return centroSaoJoseDosCampos;
  }
}
