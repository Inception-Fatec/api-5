import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persiste o token JWT (role e e-mail) entre sessões — mesmo código
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

  Future<void> save({required String token, required String role, required String email}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _emailKey);
  }
}