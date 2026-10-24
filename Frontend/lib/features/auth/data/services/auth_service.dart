import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/auth/data/services/token_storage.dart';

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
///
/// Sessão expirada: o token salvo só é aceito ao abrir o app se ainda
/// estiver dentro da validade (campo `exp` do JWT). Com o app aberto, se
/// o backend responder 401 — ou 403 com o token já vencido — desloga e
/// avisa via [onSessaoExpirada] (a UI volta para o login).
class AuthService extends ChangeNotifier {
  AuthService._() {
    ApiClient.instance.onUnauthorized = _aoReceberNaoAutorizado;
  }
  static final AuthService instance = AuthService._();

  /// Margem para considerar o token vencido um pouco antes da hora
  /// (evita aceitar um token que vence segundos depois de abrir o app).
  static const _margemExpiracao = Duration(seconds: 30);

  String? _token;
  String? _role;
  String? _email;
  String? _name;
  bool _mustChangePassword = false;
  bool _expirando = false;

  /// A UI registra aqui o que fazer quando a sessão expira (voltar para
  /// o login com aviso). Ver session_expiry.dart.
  VoidCallback? onSessaoExpirada;

  String? get token => _token;
  String? get role => _role;
  String? get email => _email;
  String? get name => _name;
  bool get mustChangePassword => _mustChangePassword;
  bool get isAuthenticated => _token != null && !tokenExpirado(_token!);

  /// Lê o `exp` (segundos desde 1970) de dentro do JWT, sem validar a
  /// assinatura — isso é papel do backend; aqui só evitamos usar um
  /// token que já sabemos que venceu. Token ilegível conta como vencido.
  static bool tokenExpirado(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false; // sem validade: deixa o backend decidir
      final vence =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return DateTime.now().toUtc().add(_margemExpiracao).isAfter(vence);
    } catch (_) {
      return true;
    }
  }

  Future<void> login(String email, String password) async {
    final data = await ApiClient.instance.postJson('/auth/login', {
      'email': email,
      'password': password,
    });

    _token = data['token'] as String;
    _role = data['role'] as String;
    _email = email;
    _name = data['name'] as String?;
    _mustChangePassword = data['mustChangePassword'] as bool? ?? false;

    ApiClient.instance.setToken(_token);
    await TokenStorage.instance
        .save(token: _token!, role: _role!, email: _email!, name: _name);
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
  /// Token vencido (ou ilegível) é apagado e o usuário vai pro login.
  Future<void> restoreSession() async {
    final token = await TokenStorage.instance.readToken();
    if (token == null) return;
    if (tokenExpirado(token)) {
      await TokenStorage.instance.clear();
      return;
    }
    final role = await TokenStorage.instance.readRole();
    final email = await TokenStorage.instance.readEmail();
    final name = await TokenStorage.instance.readName();
    _token = token;
    _role = role;
    _email = email;
    _name = name;
    ApiClient.instance.setToken(token);
    notifyListeners();
  }

  /// O backend recusou uma chamada. 401 = não autenticado: sempre
  /// desloga. 403 pode ser só falta de permissão (ex.: tela de ADM), então
  /// só desloga se o token já venceu.
  Future<void> _aoReceberNaoAutorizado(int status) async {
    final token = _token;
    if (token == null || _expirando) return;
    if (status == 403 && !tokenExpirado(token)) return;

    _expirando = true;
    try {
      await logout();
      onSessaoExpirada?.call();
    } finally {
      _expirando = false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _email = null;
    _name = null;
    _mustChangePassword = false;
    ApiClient.instance.setToken(null);
    await TokenStorage.instance.clear();
    notifyListeners();
  }
}
