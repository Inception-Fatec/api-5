/// Projeto devolvido pelo backend (só os campos que a UI usa).
/// Rótulos/cores de status ficam em `ui/styles/project_status_style.dart`.
class Project {
  final int id;
  final String name;
  final String distCode;
  final String status;
  final int createdById;

  /// Nome de quem criou (`created_by_name`); vazio em respostas antigas.
  final String createdByName;
  final DateTime createdAt;

  /// Falso quando o projeto foi excluído (soft delete) no backend.
  final bool ativo;

  /// Municípios (IBGE) do último cálculo; vazio antes de calcular (#TG-148).
  final List<String> munCodes;

  const Project({
    required this.id,
    required this.name,
    required this.distCode,
    required this.status,
    required this.createdById,
    this.createdByName = '',
    required this.createdAt,
    this.ativo = true,
    this.munCodes = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      distCode: json['dist_code'] as String? ?? '',
      status: json['status'] as String? ?? 'CRIADO',
      createdById: json['created_by_id'] as int? ?? 0,
      createdByName: (json['created_by_name'] as String? ?? '').trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      // Ausente em respostas antigas: conta como ativo.
      ativo: json['active'] as bool? ?? true,
      munCodes: (json['mun_codes'] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  /// Nome do criador vindo do backend; "Usuário #id" só se não vier.
  String get criadoPorLabel =>
      createdByName.isNotEmpty ? createdByName : 'Usuário #$createdById';

  String get dataFormatada =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
