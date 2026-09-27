import 'api_client.dart';
import 'project_model.dart';

/// Serviço de acesso a `/projects` (a base `/api/v1` já vem do
/// ApiConfig.baseUrl usado pelo ApiClient).
///
/// Colocar em: lib/services/projects_service.dart
class ProjectsService {
  final ApiClient _client;

  ProjectsService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<Project>> listar() async {
    final data = await _client.getJson('/projects');
    final list = (data as List?) ?? const [];
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /projects — espelha o ProjectCreateRequestDto do backend
  /// (só `name` e `dist_code`; status/created_by/created_at são
  /// preenchidos lá). Devolve o Project já criado, com id.
  Future<Project> criar(
      {required String name, required String distCode}) async {
    final data = await _client.postJson('/projects', {
      'name': name,
      'dist_code': distCode,
    });
    return Project.fromJson(data);
  }

  /// DELETE /projects/{id} — endpoint já existente no ProjectController.
  Future<void> excluir(int id) => _client.delete('/projects/$id');
}
