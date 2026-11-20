import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';

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
    int? gatewayProfileId,
  }) async {
    final data = await _client.postJson('/simulation/run', {
      'name': name,
      'dist_code': distCode,
      if (geometry != null) 'geometry': geometry,
      // perfil de gateway (#TG-79); sem ele, o backend usa o padrão (#TG-150)
      if (gatewayProfileId != null) 'gateway_profile_id': gatewayProfileId,
      'filter_params': filterParams,
    });
    return Project.fromJson(data);
  }

  /// GET /projects/{id}/history (#TG-85): versões do projeto, da mais
  /// recente para a mais antiga.
  Future<List<ProjectVersion>> historico(int id) async {
    final data = await _client.getJson('/projects/$id/history');
    final list = (data as List?) ?? const [];
    return list
        .map((e) => ProjectVersion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /projects/{id}/history/{versaoId}/restore: volta para uma versão
  /// antiga. Ela vira a versão mais recente e o projeto recalcula
  /// (status ENVIADO); o histórico não perde nada.
  Future<Project> restaurarVersao(int id, int versaoId) async {
    final data =
        await _client.postJson('/projects/$id/history/$versaoId/restore', {});
    return Project.fromJson(data);
  }

  /// POST /projects/{id}/recalculate (#TG-84): grava uma versão nova com
  /// [filterParams] (e a área [geometry], texto GeoJSON) e reenvia ao
  /// motor. Devolve o projeto com status ENVIADO.
  Future<Project> recalcular({
    required int id,
    required Map<String, dynamic> filterParams,
    String? geometry,
  }) async {
    final data = await _client.postJson('/projects/$id/recalculate', {
      if (geometry != null) 'geometry': geometry,
      'filter_params': filterParams,
    });
    return Project.fromJson(data);
  }

  /// POST /projects/{id}/activity (#TG-87): registra que o projeto foi
  /// aberto, para ele subir nos Recentes.
  Future<void> registrarAtividade(int id) async {
    await _client.postRaw('/projects/$id/activity', const {});
  }

  /// DELETE /projects/{id} — endpoint já existente no ProjectController.
  Future<void> excluir(int id) => _client.delete('/projects/$id');
}
