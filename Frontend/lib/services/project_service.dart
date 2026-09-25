import 'api_client.dart';
import 'project_model.dart';


class ProjectsService {
  final ApiClient _client;

  ProjectsService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<Project>> listar() async {
    final data = await _client.getJson('/projects');
    final list = (data as List?) ?? const [];
    return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }
}