import 'api_client.dart';
import 'user_model.dart';

/// Integração com o CRUD de usuários do backend (UserController):
/// GET/POST /api/v1/users e DELETE /api/v1/users/{id}. Usa o mesmo
/// [ApiClient] que o login/change-password já usam (Authorization:
/// Bearer <token> é injetado automaticamente por ele) — nada de client
/// HTTP novo. As três rotas exigem ADM (RN01/RN04,
/// @PreAuthorize("hasRole('ADM')") no backend); um 403 aqui, fora do
/// fluxo de exclusão de outro ADM, normalmente significa sessão sem
/// privilégio.
///
/// Os erros (409 e-mail duplicado, 403 sem permissão, etc.) já chegam
/// prontos como [ApiException] vindos do próprio ApiClient — ele já
/// lê o campo `message` do corpo de erro, que é exatamente o texto
/// mapeado no DoR da US-34. Não precisa de tratamento extra aqui.
class UserApiService {
  UserApiService._();
  static final UserApiService instance = UserApiService._();

  static const _basePath = '/users';

  /// CA01 — lista todos os usuários.
  Future<List<AppUser>> listUsers() async {
    final data = await ApiClient.instance.getJson(_basePath);
    return (data as List)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// CA02 — cadastra com senha padrão definida pelo ADM; o backend
  /// sempre cria com must_change_password = true.
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required UserRoleType role,
  }) async {
    final data = await ApiClient.instance.postJson(_basePath, {
      'name': name,
      'email': email,
      'password': password,
      'role': role.apiValue,
    });
    return AppUser.fromJson(data);
  }

  /// RN03/CA05/CA06 — exclusão de USER ou auto-exclusão de ADM são
  /// permitidas; excluir outro ADM retorna 403 (tratado no backend).
  Future<void> deleteUser(int id) {
    return ApiClient.instance.delete('$_basePath/$id');
  }
}