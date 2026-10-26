/// Projeto devolvido pelo backend (só os campos que a UI usa).
/// Rótulos/cores de status ficam em `ui/styles/project_status_style.dart`.
class Project {
  final int id;
  final String name;
  final String distCode;
  final String status;
  final int createdById;
  final DateTime createdAt;

  /// Falso quando o projeto foi excluído (soft delete) no backend.
  final bool ativo;

  const Project({
    required this.id,
    required this.name,
    required this.distCode,
    required this.status,
    required this.createdById,
    required this.createdAt,
    this.ativo = true,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      distCode: json['dist_code'] as String? ?? '',
      status: json['status'] as String? ?? 'CRIADO',
      createdById: json['created_by_id'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      // Ausente em respostas antigas: conta como ativo.
      ativo: json['active'] as bool? ?? true,
    );
  }

  String get criadoPorLabel => 'Usuário #$createdById';

  String get dataFormatada =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
