import 'package:flutter/foundation.dart';

/// Filtros aplicados à busca de pontos do mapa. A igualdade compara o
/// conteúdo das listas, para o mapa só refazer a busca quando algo
/// realmente mudou.
@immutable
class FiltrosPontos {
  final String distCode;
  final List<String> targetLayers;
  final List<String> conjCodes;
  final List<String> subCodes;
  final List<String> clasSub;
  final List<String> cnaeCodes;
  final List<String> bairroNames;

  const FiltrosPontos({
    required this.distCode,
    this.targetLayers = const [],
    this.conjCodes = const [],
    this.subCodes = const [],
    this.clasSub = const [],
    this.cnaeCodes = const [],
    this.bairroNames = const [],
  });

  /// True se há algum filtro além da distribuidora (e do nível de tensão
  /// "Todos", que equivale a não filtrar).
  bool get temFiltroAtivo =>
      bairroNames.isNotEmpty ||
      conjCodes.isNotEmpty ||
      subCodes.isNotEmpty ||
      clasSub.isNotEmpty ||
      cnaeCodes.isNotEmpty ||
      (targetLayers.isNotEmpty && !targetLayers.contains('all'));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FiltrosPontos &&
        other.distCode == distCode &&
        listEquals(other.targetLayers, targetLayers) &&
        listEquals(other.conjCodes, conjCodes) &&
        listEquals(other.subCodes, subCodes) &&
        listEquals(other.clasSub, clasSub) &&
        listEquals(other.cnaeCodes, cnaeCodes) &&
        listEquals(other.bairroNames, bairroNames);
  }

  @override
  int get hashCode => Object.hash(
        distCode,
        Object.hashAll(targetLayers),
        Object.hashAll(conjCodes),
        Object.hashAll(subCodes),
        Object.hashAll(clasSub),
        Object.hashAll(cnaeCodes),
        Object.hashAll(bairroNames),
      );
}
