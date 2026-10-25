import 'dart:convert';

import 'api_client.dart';
import 'api_exception.dart';

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

/// Fala com o endpoint `POST /api/v1/points/filter`, já implementado
/// no backend (Controller → Service → Repository com JdbcTemplate +
/// PostGIS). `polygon_geojson` vai como STRING (JSON serializado), e
/// a resposta traz `features` como o FeatureCollection inteiro — os
/// dois pontos em que o contrato real difere do que documentamos
/// antes, já ajustados aqui.
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
    // Quando true, pede pro backend pular a montagem do GeoJSON de
    // cada ponto — só quer saber "tem ponto ou não" (ex: validação de
    // cidade no seletor). Monta a mesma query, mas sem o custo pesado
    // de serializar geometria de dezenas de milhares de pontos que
    // ninguém vai usar nesse momento.
    bool countOnly = false,
  }) async {
    // RN01 / CA02, espelhado no cliente: pelo menos um delimitador do
    // Grupo A precisa estar preenchido antes de mandar a requisição.
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

    // target_layers agora é OPCIONAL (Etapa 2 do fluxo em 2 passos —
    // a Etapa 1 nem manda esse campo, só dist+mun).

    final payload = <String, dynamic>{
      if (distCodes != null && distCodes.isNotEmpty) 'dist_codes': distCodes,
      if (munCodes != null && munCodes.isNotEmpty) 'mun_codes': munCodes,
      if (conjCodes != null && conjCodes.isNotEmpty) 'conj_codes': conjCodes,
      if (subCodes != null && subCodes.isNotEmpty) 'sub_codes': subCodes,
      if (polygonGeoJson != null) 'polygon_geojson': jsonEncode(polygonGeoJson),
      if (targetLayers.isNotEmpty) 'target_layers': targetLayers,
      if (clasSub != null && clasSub.isNotEmpty) 'clas_sub': clasSub,
      if (cnaeCodes != null && cnaeCodes.isNotEmpty) 'cnae_codes': cnaeCodes,
      if (bairroNames != null && bairroNames.isNotEmpty) 'bairro_names': bairroNames,
      if (countOnly) 'count_only': true,
    };

    late final Map<String, dynamic> corpo;
    try {
      corpo = await ApiClient.instance.postJson('/points/filter', payload);
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw PointsFilterException('Requisição inválida — confira os filtros selecionados.');
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        throw PointsFilterException('Sessão expirada ou sem permissão — faça login novamente.');
      }
      throw PointsFilterException('Não foi possível buscar os pontos agora (erro ${e.statusCode}).');
    } catch (_) {
      throw PointsFilterException(
        'Não foi possível conectar ao servidor. Verifique sua conexão ou se o backend está no ar.',
      );
    }

    // O backend devolve "features" como o FeatureCollection INTEIRO
    // ({"type": "FeatureCollection", "features": [...]}), não como
    // array direto — por isso o acesso ['features']['features'].
    // Blindado contra o formato vindo como lista solta também (podia
    // acontecer em respostas de count_only antes da correção no
    // backend) — trata como "sem pontos" em vez de quebrar.
    final featuresRaw = corpo['features'];
    final featureCollection = featuresRaw is Map<String, dynamic> ? featuresRaw : null;
    final listaFeatures = featureCollection?['features'] as List? ?? const [];
    return PointsFilterResult(
      totalPoints: (corpo['total_points'] as num?)?.toInt() ?? 0,
      features: List<Map<String, dynamic>>.from(listaFeatures),
    );
  }
}