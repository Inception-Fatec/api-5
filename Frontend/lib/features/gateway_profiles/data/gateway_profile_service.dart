import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile.dart';

/// Acesso a `/gateway-profiles` (#TG-78): listar, criar, editar e excluir.
class GatewayProfileService {
  final ApiClient _client;

  GatewayProfileService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// Perfis ativos, com o padrão primeiro e os demais em ordem alfabética.
  Future<List<GatewayProfile>> listar() async {
    final data = await _client.getJson('/gateway-profiles');
    final lista = [
      for (final item in (data as List?) ?? const [])
        if (item is Map<String, dynamic>) GatewayProfile.fromJson(item),
    ]..sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return lista;
  }

  Future<GatewayProfile> criar(GatewayProfile perfil) async =>
      GatewayProfile.fromJson(
          await _client.postJson('/gateway-profiles', perfil.toJson()));

  Future<GatewayProfile> editar(int id, GatewayProfile perfil) async =>
      GatewayProfile.fromJson(
          await _client.putJson('/gateway-profiles/$id', perfil.toJson()));

  Future<void> excluir(int id) => _client.delete('/gateway-profiles/$id');
}
