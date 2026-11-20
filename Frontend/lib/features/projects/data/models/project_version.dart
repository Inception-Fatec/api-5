import 'package:tecsys_app/core/utils/data_backend.dart';

/// Uma versão do projeto, de GET /projects/{id}/history (#TG-85): a área
/// desenhada e os filtros usados num cálculo. A lista vem da mais recente
/// para a mais antiga; o mapa abre a versão em uso ([versaoEmUso], #TG-86).
class ProjectVersion {
  final int id;
  final DateTime? criadoEm;
  final Map<String, dynamic> filterParams;

  /// Perfil de gateway da versão; null enquanto não for salvo.
  final String? gatewayProfile;

  /// Área desenhada (GeoJSON Polygon ou MultiPolygon); null = sem área.
  final Map<String, dynamic>? polygon;

  /// Versão em uso: a que o relatório mostra (`current` do backend).
  final bool emUso;

  const ProjectVersion({
    required this.id,
    this.criadoEm,
    this.filterParams = const {},
    this.gatewayProfile,
    this.polygon,
    this.emUso = false,
  });

  /// Índice da versão em uso na lista. Backend antigo (sem `current`): a
  /// primeira, a mais recente.
  static int indiceEmUso(List<ProjectVersion> versoes) {
    final i = versoes.indexWhere((v) => v.emUso);
    return i < 0 ? 0 : i;
  }

  /// A versão em uso, ou null se a lista estiver vazia.
  static ProjectVersion? versaoEmUso(List<ProjectVersion> versoes) =>
      versoes.isEmpty ? null : versoes[indiceEmUso(versoes)];

  factory ProjectVersion.fromJson(Map<String, dynamic> json) {
    final filtros = json['filter_params'];
    final area = json['polygon'];
    return ProjectVersion(
      id: json['id'] as int,
      criadoEm: lerDataBackend(json['created_at']?.toString()),
      filterParams:
          filtros is Map ? Map<String, dynamic>.from(filtros) : const {},
      gatewayProfile: json['gateway_profile'] as String?,
      polygon: area is Map ? Map<String, dynamic>.from(area) : null,
      emUso: json['current'] == true,
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
}
