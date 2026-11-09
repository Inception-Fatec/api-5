class MapConfig {
  MapConfig._();

  
  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const reliefTileUrl =
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/ASTER_GDEM_Greyscale_Shaded_Relief/default/GoogleMapsCompatible_Level12/{z}/{y}/{x}.jpg';
  static const reliefMaxNativeZoom = 12;
  static const reliefOpacity = 0.6;
  static const userAgentPackage = 'com.tecsys.frontend_tecsys';

  
  static const defaultZoom = 12.0;
  static const minZoom = 3.0;
  static const maxZoom = 19.0;

  static const zoomButtonStep = 1.0;

  static const scrollWheelVelocity = 0.012;

  static const scrollZoomSettle = Duration(milliseconds: 250);

  static const minZoomToSearch = 13.0;

  static const overviewCellDegrees = 0.01;

  static const overviewTimeout = Duration(seconds: 60);

  static const overviewFitPadding = 56.0;

  static const clusterPixelSize = 72.0;

  static const openZoom = 12.0;

  static const minZoomIndividual = 16.0;

  static const detailPixelSize = 56.0;

  static const detailCellsPerBubble = 3;

  static const detailFetchMargin = 0.25;

  static const clusterTapZoomStep = 2.0;

  static const searchDebounce = Duration(milliseconds: 500);
  static const maxRenderedPoints = 800;
  static const revealBatchSize = 15;
  static const revealBatchDelay = Duration(milliseconds: 16);

  static const savedConfirmationDelay = Duration(seconds: 2);

  static const suggestionDebounce = Duration(milliseconds: 350);
  static const suggestionMinChars = 2;
}
