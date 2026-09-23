import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'token_storage.dart';

/// Estado de autenticação único do app (web e mobile compartilham a
/// mesma instância e a mesma lógica — só a UI que chama muda).
/// Espelha o AuthResponseDto do backend: token, role e
/// mustChangePassword (RN02) chegam juntos na resposta do /login.
///
/// [_email] não vem do backend (AuthResponseDto não inclui id nem
/// e-mail de volta) — é só o e-mail que o próprio usuário digitou no
/// login, guardado aqui porque é a única forma que o front tem de
/// saber "este registro da lista de usuários sou eu mesmo" (RN03,
/// tela de gestão de usuários) sem o backend expor um id.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _token;
  String? _role;
  String? _email;
  bool _mustChangePassword = false;

  String? get token => _token;
  String? get role => _role;
  String? get email => _email;
  bool get mustChangePassword => _mustChangePassword;
  bool get isAuthenticated => _token != null;

  Future<void> login(String email, String password) async {
    final data = await ApiClient.instance.postJson('/auth/login', {
      'email': email,
      'password': password,
    });

    _token = data['token'] as String;
    _role = data['role'] as String;
    _email = email;
    _mustChangePassword = data['mustChangePassword'] as bool? ?? false;

    ApiClient.instance.setToken(_token);
    await TokenStorage.instance.save(token: _token!, role: _role!, email: _email!);
    notifyListeners();
  }

  /// Task #53 — modal de primeiro acesso chama isso. Requer estar
  /// autenticado (o ApiClient já injeta o Bearer token setado no
  /// login acima).
  Future<void> changePassword(String newPassword) async {
    await ApiClient.instance.postRaw('/auth/change-password', {
      'newPassword': newPassword,
    });
    _mustChangePassword = false;
    notifyListeners();
  }

  /// Chamar no boot do app (ex.: splash / main) pra manter o usuário
  /// logado entre sessões em vez de sempre cair na tela de login.
  Future<void> restoreSession() async {
    final token = await TokenStorage.instance.readToken();
    final role = await TokenStorage.instance.readRole();
    final email = await TokenStorage.instance.readEmail();
    if (token != null) {
      _token = token;
      _role = role;
      _email = email;
      ApiClient.instance.setToken(token);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _email = null;
    _mustChangePassword = false;
    ApiClient.instance.setToken(null);
    await TokenStorage.instance.clear();
    notifyListeners();
  }
}