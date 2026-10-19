import 'dart:convert';

import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/core/network/api_exception.dart';

class PointsFilterResult {
  final int totalPoints;
  final List<Map<String, dynamic>> features;
  const PointsFilterResult({required this.totalPoints, required this.features});
}

class PointsFilterException implements Exception {
  final String message;
  PointsFilterException(this.message);
  @override
  String toString() => message;
}

class PointsFilterService {
  Future<PointsFilterResult> buscarPontos({
    List<String>? distCodes,
    List<String>? munCodes,
    List<String>? conjCodes,
    List<String>? subCodes,
    Map<String, dynamic>? polygonGeoJson,
    List<String> targetLayers = const [],
    List<String>? clasSub,
    List<String>? cnaeCodes,
    List<String>? bairroNames,
    bool countOnly = false,
  }) async {
    final temDelimitador = (distCodes?.isNotEmpty ?? false) ||
        (munCodes?.isNotEmpty ?? false) ||
        (conjCodes?.isNotEmpty ?? false) ||
        (subCodes?.isNotEmpty ?? false) ||
        polygonGeoJson != null;

    if (!temDelimitador) {
      throw PointsFilterException(
        'Informe ao menos uma Empresa, Município, Conjunto, Subestação ou desenhe uma área no mapa.',
      );
    }

    final payload = <String, dynamic>{
      if (distCodes != null && distCodes.isNotEmpty) 'dist_codes': distCodes,
      if (munCodes != null && munCodes.isNotEmpty) 'mun_codes': munCodes,
      if (conjCodes != null && conjCodes.isNotEmpty) 'conj_codes': conjCodes,
      if (subCodes != null && subCodes.isNotEmpty) 'sub_codes': subCodes,
      if (polygonGeoJson != null) 'polygon_geojson': jsonEncode(polygonGeoJson),
      if (targetLayers.isNotEmpty) 'target_layers': targetLayers,
      if (clasSub != null && clasSub.isNotEmpty) 'clas_sub': clasSub,
      if (cnaeCodes != null && cnaeCodes.isNotEmpty) 'cnae_codes': cnaeCodes,
      if (bairroNames != null && bairroNames.isNotEmpty)
        'bairro_names': bairroNames,
      if (countOnly) 'count_only': true,
    };

    late final Map<String, dynamic> corpo;
    try {
      corpo = await ApiClient.instance.postJson('/points/filter', payload);
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw PointsFilterException(
            'Requisição inválida — confira os filtros selecionados.');
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw PointsFilterException(
            'Sessão expirada ou sem permissão — faça login novamente.');
      }
      throw PointsFilterException(
          'Não foi possível buscar os pontos agora (erro ${e.statusCode}).');
    } catch (_) {
      throw PointsFilterException(
        'Não foi possível conectar ao servidor. Verifique sua conexão ou se o backend está no ar.',
      );
    }

    final featuresRaw = corpo['features'];
    final featureCollection =
        featuresRaw is Map<String, dynamic> ? featuresRaw : null;
    final listaFeatures = featureCollection?['features'] as List? ?? const [];
    return PointsFilterResult(
      totalPoints: (corpo['total_points'] as num?)?.toInt() ?? 0,
      features: List<Map<String, dynamic>>.from(listaFeatures),
    );
  }

  /// Autocompletar de Bairro — `GET /api/v1/bairros`, nomes reais do
  /// banco que batem com o texto digitado, dentro das cidades dadas.
  Future<List<String>> buscarSugestoesBairro({
    required List<String> munCodes,
    required String texto,
  }) async {
    if (munCodes.isEmpty) return const [];
    final query = munCodes
        .map((m) => 'mun_codes=${Uri.encodeQueryComponent(m)}')
        .join('&');
    final path = '/bairros?$query&q=${Uri.encodeQueryComponent(texto)}';
    try {
      final corpo =
          await ApiClient.instance.getJson(path) as Map<String, dynamic>?;
      final lista = corpo?['bairros'] as List? ?? const [];
      return lista.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}
