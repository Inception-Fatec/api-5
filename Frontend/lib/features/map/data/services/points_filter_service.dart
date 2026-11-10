import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/core/network/api_exception.dart';

/// Totais do mapa no formato do relatório: pontos = consumidores (o que o
/// motor cobre), candidatos = transformadores (onde pode ir gateway).
/// Trechos de rede e subestações são só desenho e não entram aqui.
@immutable
class ContagemPontos {
  final int pontos;
  final int candidatos;

  const ContagemPontos({required this.pontos, required this.candidatos});

  static const zero = ContagemPontos(pontos: 0, candidatos: 0);

  /// 31084 -> "31.084".
  static String numero(int n) => n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  String get textoPontos =>
      '${numero(pontos)} ${pontos == 1 ? 'ponto' : 'pontos'} a cobrir';

  String get textoCandidatos =>
      '${numero(candidatos)} ${candidatos == 1 ? 'local para gateway' : 'locais para gateway'}';

  /// "31.084 pontos a cobrir · 11.081 locais para gateway"
  String get texto => '$textoPontos · $textoCandidatos';

  @override
  bool operator ==(Object other) =>
      other is ContagemPontos &&
      other.pontos == pontos &&
      other.candidatos == candidatos;

  @override
  int get hashCode => Object.hash(pontos, candidatos);
}

class PointsFilterResult {
  /// Só consumidores: os pontos que o motor precisa cobrir.
  final int totalPoints;

  /// Transformadores: onde o motor pode instalar gateway.
  final int totalCandidates;

  /// Trechos de rede e subestações (só desenho, não entram no cálculo).
  final int totalNetwork;

  final List<Map<String, dynamic>> features;

  ContagemPontos get contagem =>
      ContagemPontos(pontos: totalPoints, candidatos: totalCandidates);

  const PointsFilterResult({
    required this.totalPoints,
    this.totalCandidates = 0,
    this.totalNetwork = 0,
    required this.features,
  });
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
    List<String>? coverageLayers,
    List<String>? candidateLayers,
    bool countOnly = false,
    double? clusterCell,
    int? limit,
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
      if (coverageLayers != null && coverageLayers.isNotEmpty)
        'coverage_layers': coverageLayers,
      if (candidateLayers != null && candidateLayers.isNotEmpty)
        'candidate_layers': candidateLayers,
      if (countOnly) 'count_only': true,
      if (clusterCell != null) 'cluster_cell': clusterCell,
      if (limit != null) 'limit': limit,
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
      totalCandidates: (corpo['total_candidates'] as num?)?.toInt() ?? 0,
      totalNetwork: (corpo['total_network'] as num?)?.toInt() ?? 0,
      features: List<Map<String, dynamic>>.from(listaFeatures),
    );
  }

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
