/// Parâmetros fixos do mapa de pontos (tiles, limites de zoom e de busca).
class MapConfig {
  MapConfig._();

  // Camadas de tiles
  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const reliefTileUrl =
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/ASTER_GDEM_Greyscale_Shaded_Relief/default/GoogleMapsCompatible_Level12/{z}/{y}/{x}.jpg';
  static const reliefMaxNativeZoom = 12;
  static const reliefOpacity = 0.6;
  static const userAgentPackage = 'com.tecsys.frontend_tecsys';

  // Câmera
  static const defaultZoom = 12.0;
  static const minZoom = 3.0;
  static const maxZoom = 19.0;

  /// Abaixo deste zoom a área visível é grande demais: não busca pontos.
  static const minZoomToSearch = 13.0;

  // Busca e renderização dos pontos
  static const searchDebounce = Duration(milliseconds: 500);
  static const maxRenderedPoints = 800;
  static const revealBatchSize = 5;
  static const revealBatchDelay = Duration(milliseconds: 16);

  /// Tempo mostrando a confirmação de "Salvo" antes de fechar a tela.
  static const savedConfirmationDelay = Duration(seconds: 2);

  // Autocompletar de bairro
  static const suggestionDebounce = Duration(milliseconds: 350);
  static const suggestionMinChars = 2;
}
