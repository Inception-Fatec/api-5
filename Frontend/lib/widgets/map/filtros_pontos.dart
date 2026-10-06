
class FiltrosPontos {
  final String distCode;

  final List<String> munCodes;

  final List<String> targetLayers;
  final List<String> conjCodes;
  final List<String> subCodes;
  final List<String> clasSub; 
  final List<String> cnaeCodes;
  final List<String> bairroNames; 

  const FiltrosPontos({
    required this.distCode,
    this.munCodes = const [],
    this.targetLayers = const [],
    this.conjCodes = const [],
    this.subCodes = const [],
    this.clasSub = const [],
    this.cnaeCodes = const [],
    this.bairroNames = const [],
  });

  FiltrosPontos copiarCom({
    String? distCode,
    List<String>? munCodes,
    List<String>? targetLayers,
    List<String>? conjCodes,
    List<String>? subCodes,
    List<String>? clasSub,
    List<String>? cnaeCodes,
    List<String>? bairroNames,
  }) {
    return FiltrosPontos(
      distCode: distCode ?? this.distCode,
      munCodes: munCodes ?? this.munCodes,
      targetLayers: targetLayers ?? this.targetLayers,
      conjCodes: conjCodes ?? this.conjCodes,
      subCodes: subCodes ?? this.subCodes,
      clasSub: clasSub ?? this.clasSub,
      cnaeCodes: cnaeCodes ?? this.cnaeCodes,
      bairroNames: bairroNames ?? this.bairroNames,
    );
  }

  bool _mesmaLista(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FiltrosPontos &&
        other.distCode == distCode &&
        _mesmaLista(other.targetLayers, targetLayers) &&
        _mesmaLista(other.conjCodes, conjCodes) &&
        _mesmaLista(other.subCodes, subCodes) &&
        _mesmaLista(other.clasSub, clasSub) &&
        _mesmaLista(other.cnaeCodes, cnaeCodes) &&
        _mesmaLista(other.bairroNames, bairroNames);
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