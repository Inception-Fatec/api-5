/// Uma versão do projeto, de GET /projects/{id}/history (#TG-85): a área
/// desenhada e os filtros usados num cálculo. A lista vem da mais recente
/// para a mais antiga; o mapa abre a primeira (#TG-86).
class ProjectVersion {
  final int id;
  final DateTime? criadoEm;
  final Map<String, dynamic> filterParams;

  /// Perfil de gateway da versão; null enquanto não for salvo.
  final String? gatewayProfile;

  /// Área desenhada (GeoJSON Polygon ou MultiPolygon); null = sem área.
  final Map<String, dynamic>? polygon;

  const ProjectVersion({
    required this.id,
    this.criadoEm,
    this.filterParams = const {},
    this.gatewayProfile,
    this.polygon,
  });

  factory ProjectVersion.fromJson(Map<String, dynamic> json) {
    final filtros = json['filter_params'];
    final area = json['polygon'];
    return ProjectVersion(
      id: json['id'] as int,
      criadoEm: _data(json['created_at']?.toString()),
      filterParams:
          filtros is Map ? Map<String, dynamic>.from(filtros) : const {},
      gatewayProfile: json['gateway_profile'] as String?,
      polygon: area is Map ? Map<String, dynamic>.from(area) : null,
    );
  }

  List<String> lista(String chave) {
    final v = filterParams[chave];
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> get munCodes => lista('mun_codes');
  List<String> get targetLayers => lista('target_layers');
  List<String> get conjCodes => lista('conj_codes');
  List<String> get subCodes => lista('sub_codes');
  List<String> get clasSub => lista('clas_sub');
  List<String> get cnaeCodes => lista('cnae_codes');
  List<String> get bairroNames => lista('bairro_names');

  /// "dd/MM/yyyy HH:mm:ss" (formato do backend) ou ISO 8601.
  static DateTime? _data(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})(?: (\d{2}):(\d{2})(?::(\d{2}))?)?$')
        .firstMatch(texto.trim());
    if (br == null) return DateTime.tryParse(texto);
    int n(int g) => int.tryParse(br.group(g) ?? '') ?? 0;
    return DateTime(n(3), n(2), n(1), n(4), n(5), n(6));
  }
}
