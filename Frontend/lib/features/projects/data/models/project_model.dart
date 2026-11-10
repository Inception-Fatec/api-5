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
  final DateTime? updatedAt;

  /// Falso quando o projeto foi excluído (soft delete) no backend.
  final bool ativo;

  /// Municípios (IBGE) do último cálculo; vazio antes de calcular (#TG-148).
  final List<String> munCodes;

  /// Motivo da falha quando o status é FALHA (ex.: motor fora do ar).
  final String? statusMessage;

  /// Atividade mais recente (criar, recalcular, abrir o relatório), para
  /// os Recentes (#TG-88); null em respostas antigas.
  final DateTime? lastActivityAt;

  const Project({
    required this.id,
    required this.name,
    required this.distCode,
    required this.status,
    required this.createdById,
    this.createdByName = '',
    required this.createdAt,
    this.updatedAt,
    this.ativo = true,
    this.munCodes = const [],
    this.statusMessage,
    this.lastActivityAt,
  });

  /// Quando o projeto teve atividade pela última vez (sem o dado, a criação).
  DateTime get ultimaAtividade => lastActivityAt ?? createdAt;

  Project copyWith({String? status, DateTime? lastActivityAt}) => Project(
        id: id,
        name: name,
        distCode: distCode,
        status: status ?? this.status,
        createdById: createdById,
        createdByName: createdByName,
        createdAt: createdAt,
        ativo: ativo,
        munCodes: munCodes,
        statusMessage: statusMessage,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );

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
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      // Ausente em respostas antigas: conta como ativo.
      ativo: json['active'] as bool? ?? true,
      munCodes: (json['mun_codes'] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      statusMessage: (json['status_message'] as String?)?.trim(),
      lastActivityAt:
          DateTime.tryParse(json['last_activity_at']?.toString() ?? '')?.toLocal(),
    );
  }

  /// Nome do criador vindo do backend; "Usuário #id" só se não vier.
  String get criadoPorLabel =>
      createdByName.isNotEmpty ? createdByName : 'Usuário #$createdById';

  String get dataFormatada =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
