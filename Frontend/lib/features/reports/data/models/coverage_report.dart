import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// Relatório de cobertura de um projeto, no formato devolvido por
/// `GET /api/v1/reports/projects/{id}/coverage` (branch TG-9):
///
/// ```json
/// { "projectId": 1,
///   "summary":  { "total_points": ..., "gateway_range_m": 4000, ... },
///   "gateways": [ { "order": 1, "id": "...", "latitude": ..., ... } ],
///   "points":   { "covered":   [["id", lon, lat], ...],
///                 "uncovered": [["id", lon, lat], ...] } }
/// ```
///
/// Notas sobre o que o back entrega hoje:
/// - os pontos vêm compactos, com LONGITUDE antes da latitude;
/// - `type`, `posto` e `sub` dos gateways são @JsonIgnore no motor e
///   não chegam: a tela trata todos como "Gateway";
/// - os filtros do cálculo ficam em `project_history.filter_params`, mas
///   a rota não os devolve. Se o back passar a mandar `filter_params`
///   (ou `filterParams`) na resposta, o texto introdutório usa; sem
///   isso, [filters] é null e a tela avisa que não foram informados.
class CoverageReport {
  final ReportSummary summary;
  final List<ReportGateway> gateways;

  /// Pontos atendidos / sem cobertura. Guardados como coordenadas
  /// compactas ([PointCloud]) porque podem ser centenas de milhares.
  final PointCloud coveredPoints;
  final PointCloud uncoveredPoints;

  /// Filtros usados no cálculo, ou null se o servidor não informou.
  final ReportFilters? filters;

  const CoverageReport({
    required this.summary,
    required this.gateways,
    required this.coveredPoints,
    required this.uncoveredPoints,
    required this.filters,
  });

  /// "Tudo zerado" (o motor devolve 200 sem pontos): estado vazio.
  bool get isEmpty => summary.totalPoints == 0;

  /// Região que enquadra o estudo: todos os pontos (atendidos e sem
  /// cobertura) mais os gateways. Sem pontos, os gateways com o alcance
  /// de cada um ao redor. Null se não houver nada para enquadrar.
  LatLngBounds? get focusBounds {
    final corners = <LatLng>[];
    for (final cloud in [coveredPoints, uncoveredPoints]) {
      final b = cloud.bounds;
      if (b != null) corners..add(b.southWest)..add(b.northEast);
    }
    if (corners.isNotEmpty) {
      for (final g in gateways) {
        corners.add(g.position);
      }
      return LatLngBounds.fromPoints(corners);
    }
    if (gateways.isEmpty) return null;

    final rangeM = summary.gatewayRangeM.toDouble();
    // ~111,32 km por grau de latitude; a longitude encolhe com cos(lat).
    final dLat = rangeM / 111320.0;
    for (final g in gateways) {
      final cosLat = math.max(0.01, math.cos(g.position.latitudeInRad).abs());
      final dLng = rangeM / (111320.0 * cosLat);
      corners
        ..add(LatLng(g.position.latitude - dLat, g.position.longitude - dLng))
        ..add(LatLng(g.position.latitude + dLat, g.position.longitude + dLng));
    }
    return LatLngBounds.fromPoints(corners);
  }

  factory CoverageReport.fromJson(Map<String, dynamic> json) {
    final points = _map(json['points']);
    return CoverageReport(
      summary: ReportSummary.fromJson(_map(json['summary'])),
      gateways: _list(json['gateways'])
          .map((e) => ReportGateway.fromJson(_map(e)))
          .toList(growable: false),
      coveredPoints: PointCloud.fromCompactList(_list(points['covered'])),
      uncoveredPoints: PointCloud.fromCompactList(_list(points['uncovered'])),
      filters: ReportFilters.fromReportJson(json),
    );
  }
}

class ReportSummary {
  final int totalPoints;
  final int totalCandidates;
  final int selectedGateways;
  final int coveredPoints;
  final int uncoveredPoints;
  final double coveragePercentage;

  /// Alcance do gateway usado no cálculo, em metros. Vem sempre da
  /// resposta — nunca é fixado no app (parâmetro de RF).
  final int gatewayRangeM;

  const ReportSummary({
    required this.totalPoints,
    required this.totalCandidates,
    required this.selectedGateways,
    required this.coveredPoints,
    required this.uncoveredPoints,
    required this.coveragePercentage,
    required this.gatewayRangeM,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      totalPoints: _int(json['total_points']),
      totalCandidates: _int(json['total_candidates']),
      selectedGateways: _int(json['selected_gateways']),
      coveredPoints: _int(json['covered_points']),
      uncoveredPoints: _int(json['uncovered_points']),
      coveragePercentage: _double(json['coverage_percentage']),
      gatewayRangeM: _int(json['gateway_range_m']),
    );
  }
}

class ReportGateway {
  /// Ordem de escolha (1 = o que mais cobre).
  final int order;
  final String id;

  /// SUB, UNTRMT ou UNTRAT — pode vir nulo (ver nota em [CoverageReport]).
  final String? type;
  final String? posto;
  final String? sub;
  final LatLng position;
  final int newPointsCovered;
  final int cumulativePointsCovered;
  final double cumulativeCoveragePercentage;

  const ReportGateway({
    required this.order,
    required this.id,
    required this.position,
    required this.newPointsCovered,
    required this.cumulativePointsCovered,
    required this.cumulativeCoveragePercentage,
    this.type,
    this.posto,
    this.sub,
  });

  factory ReportGateway.fromJson(Map<String, dynamic> json) {
    return ReportGateway(
      order: _int(json['order']),
      id: json['id']?.toString() ?? '',
      type: json['type'] as String?,
      posto: json['posto']?.toString(),
      sub: json['sub']?.toString(),
      position: LatLng(_double(json['latitude']), _double(json['longitude'])),
      newPointsCovered: _int(json['new_points_covered']),
      cumulativePointsCovered: _int(json['cumulative_points_covered']),
      cumulativeCoveragePercentage:
          _double(json['cumulative_coverage_percentage']),
    );
  }
}

/// Conjunto de pontos guardado como um único `Float64List` (x, y
/// intercalados) em coordenadas Web Mercator "unitárias" (0..1 no mundo
/// todo). Com centenas de milhares de pontos, uma lista de objetos
/// custaria dezenas de MB e travaria o parse; assim o desenho só
/// multiplica pela escala do zoom (ver `PointsPainter`).
class PointCloud {
  /// x0, y0, x1, y1, ... em Mercator unitário (origem no canto
  /// noroeste do mundo: x cresce para leste, y para o sul).
  final Float64List unitXY;

  const PointCloud(this.unitXY);

  static final PointCloud empty = PointCloud(Float64List(0));

  int get length => unitXY.length ~/ 2;
  bool get isEmpty => unitXY.isEmpty;

  /// Lê o formato compacto do back: cada item é `[id, longitude,
  /// latitude]` (longitude primeiro). Ignora itens malformados.
  factory PointCloud.fromCompactList(List<Object?> items) {
    final buffer = Float64List(items.length * 2);
    var n = 0;
    for (final item in items) {
      if (item is! List || item.length < 3) continue;
      final lng = item[1];
      final lat = item[2];
      if (lng is! num || lat is! num) continue;
      buffer[n++] = unitX(lng.toDouble());
      buffer[n++] = unitY(lat.toDouble());
    }
    return PointCloud(Float64List.sublistView(buffer, 0, n));
  }

  /// Monta a nuvem a partir de pares lat/lng (usado nos testes).
  factory PointCloud.fromLatLngs(Iterable<LatLng> points) {
    final list = points.toList(growable: false);
    final buffer = Float64List(list.length * 2);
    for (var i = 0; i < list.length; i++) {
      buffer[i * 2] = unitX(list[i].longitude);
      buffer[i * 2 + 1] = unitY(list[i].latitude);
    }
    return PointCloud(buffer);
  }

  /// Caixa que contém todos os pontos, ou null se a nuvem é vazia.
  LatLngBounds? get bounds {
    if (isEmpty) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < unitXY.length; i += 2) {
      final x = unitXY[i], y = unitXY[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return LatLngBounds(
      LatLng(latFromUnitY(maxY), lngFromUnitX(minX)),
      LatLng(latFromUnitY(minY), lngFromUnitX(maxX)),
    );
  }

  /// Distância típica entre pontos vizinhos, em metros, estimada pela
  /// área da caixa que contém a nuvem dividida pelo número de pontos.
  /// Null com menos de 2 pontos. Serve para dimensionar a mancha.
  double? get typicalSpacingMeters {
    if (length < 2) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < unitXY.length; i += 2) {
      final x = unitXY[i], y = unitXY[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final midLat = latFromUnitY((minY + maxY) / 2);
    // Em Mercator, 1 unidade = circunferência da Terra * cos(lat) no local.
    final metersPerUnit =
        _earthCircumferenceM * math.cos(midLat * math.pi / 180.0).abs();
    final w = (maxX - minX) * metersPerUnit;
    final h = (maxY - minY) * metersPerUnit;
    final area = w * h;
    if (area <= 0) return math.max(w, h) / length;
    return math.sqrt(area / length);
  }

  static const _earthCircumferenceM = 40075016.686;

  // --- Web Mercator unitário ---------------------------------------------
  static const _maxLat = 85.0511287798;

  static double unitX(double lng) => (lng + 180.0) / 360.0;

  static double unitY(double lat) {
    final clamped = lat.clamp(-_maxLat, _maxLat).toDouble();
    final rad = clamped * math.pi / 180.0;
    return 0.5 - math.log(math.tan(math.pi / 4 + rad / 2)) / (2 * math.pi);
  }

  static double lngFromUnitX(double x) => x * 360.0 - 180.0;

  static double latFromUnitY(double y) {
    final n = math.pi * (1 - 2 * y);
    return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }
}

/// Filtros usados no cálculo.
class ReportFilters {
  final List<String> distCodes;
  final List<String> munCodes;
  final List<String> conjCodes;
  final List<String> subCodes;
  final List<String> targetLevels;
  final List<String> clasSub;
  final List<String> cnaeCodes;
  final List<String> bairroNames;
  final bool hasPolygon;

  const ReportFilters({
    this.distCodes = const [],
    this.munCodes = const [],
    this.conjCodes = const [],
    this.subCodes = const [],
    this.targetLevels = const [],
    this.clasSub = const [],
    this.cnaeCodes = const [],
    this.bairroNames = const [],
    this.hasPolygon = false,
  });

  /// Nenhum filtro (lista vazia/ausente = "sem filtro" no motor).
  bool get isEmpty =>
      distCodes.isEmpty &&
      munCodes.isEmpty &&
      conjCodes.isEmpty &&
      subCodes.isEmpty &&
      targetLevels.isEmpty &&
      clasSub.isEmpty &&
      cnaeCodes.isEmpty &&
      bairroNames.isEmpty &&
      !hasPolygon;

  /// Filtros da resposta do relatório: lê `filter_params` (ou
  /// `filterParams`) se o back mandar; senão devolve null.
  static ReportFilters? fromReportJson(Map<String, dynamic> json) {
    final raw = json['filter_params'] ?? json['filterParams'];
    return raw is Map<String, dynamic> ? ReportFilters.fromFilterParams(raw) : null;
  }

  /// Formato salvo em `project_history.filter_params` (o mesmo que o
  /// app envia em `/simulation/run`): chaves em snake_case e
  /// `target_layers` com "all", "alto", "medio" ou "baixo".
  factory ReportFilters.fromFilterParams(Map<String, dynamic> json) {
    final layers =
        _strings(json['target_layers']).map((e) => e.toLowerCase()).toList();
    // "all" (ou vazio) = todos os níveis = sem filtro de nível.
    final levels = layers.contains('all')
        ? const <String>[]
        : layers
            .where(_levels.contains)
            .map((e) => e.toUpperCase())
            .toList(growable: false);
    final polygon = json['polygon_geojson'];
    return ReportFilters(
      distCodes: _strings(json['dist_codes']),
      munCodes: _strings(json['mun_codes']),
      conjCodes: _strings(json['conj_codes']),
      subCodes: _strings(json['sub_codes']),
      targetLevels: levels,
      clasSub: _strings(json['clas_sub']),
      cnaeCodes: _strings(json['cnae_codes']),
      bairroNames: _strings(json['bairro_names']),
      hasPolygon: (polygon is String && polygon.trim().isNotEmpty) ||
          (polygon is Map && polygon.isNotEmpty),
    );
  }

  static const _levels = {'alto', 'medio', 'baixo'};
}

/// Decodifica o corpo (JSON em bytes UTF-8) num [CoverageReport].
/// Função de topo de propósito: `compute` só aceita funções assim, e
/// com centenas de milhares de pontos o parse não pode rodar na thread
/// da UI. Lança [FormatException] se o corpo não for um objeto JSON.
CoverageReport parseCoverageReportBytes(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Relatório em formato inesperado.');
  }
  return CoverageReport.fromJson(decoded);
}

// --- helpers de leitura tolerante ----------------------------------------

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

List<Object?> _list(Object? v) => v is List ? v : const <Object?>[];

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

double _double(Object? v) => (v as num?)?.toDouble() ?? 0.0;

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList(growable: false) : const [];
