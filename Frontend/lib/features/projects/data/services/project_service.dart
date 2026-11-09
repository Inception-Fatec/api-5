import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';

/// Serviço de acesso a `/projects` (a base `/api/v1` já vem do
/// ApiConfig.baseUrl usado pelo ApiClient).
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

  /// POST /simulation/run — espelha o SimulationRunRequestDto do backend:
  /// `name`, `dist_code`, `geometry` (polígono da área como texto GeoJSON,
  /// gravado no histórico do projeto) e `filter_params`. Devolve o
  /// Project já criado, com id.
  Future<Project> criar({
    required String name,
    required String distCode,
    required Map<String, dynamic> filterParams,
    String? geometry,
  }) async {
    final data = await _client.postJson('/simulation/run', {
      'name': name,
      'dist_code': distCode,
      if (geometry != null) 'geometry': geometry,
      'filter_params': filterParams,
    });
    return Project.fromJson(data);
  }

  /// DELETE /projects/{id} — endpoint já existente no ProjectController.
  Future<void> excluir(int id) => _client.delete('/projects/$id');
}
