import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste o token JWT (role, e-mail e se ainda falta trocar a senha
/// do primeiro acesso) entre sessões — mesmo código
/// pra web e mobile, o flutter_secure_storage escolhe o backend certo
/// em cada plataforma (Keychain/Keystore no mobile, storage
/// criptografado no navegador na web).
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _emailKey = 'auth_email';
  static const _nameKey = 'auth_name';
  static const _mustChangeKey = 'auth_must_change_password';

  Future<void> save(
      {required String token,
      required String role,
      required String email,
      String? name,
      bool mustChangePassword = false}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _emailKey, value: email);
    if (name != null) await _storage.write(key: _nameKey, value: name);
    await saveMustChangePassword(mustChangePassword);
  }

  Future<void> saveMustChangePassword(bool value) =>
      _storage.write(key: _mustChangeKey, value: value.toString());

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<String?> readName() => _storage.read(key: _nameKey);

  Future<bool> readMustChangePassword() async =>
      await _storage.read(key: _mustChangeKey) == 'true';

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _mustChangeKey);
  }
}
