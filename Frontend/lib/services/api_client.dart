import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Resolve a base URL da API conforme a plataforma que está rodando
/// o app, já que "localhost" significa coisas diferentes em cada uma
/// durante o desenvolvimento local (backend rodando na porta 8081):
/// - Web e iOS/desktop: localhost aponta pra própria máquina.
/// - Emulador Android: localhost do emulador não é o localhost da
///   máquina host — precisa do alias especial 10.0.2.2.
/// - Dispositivo físico: nenhum dos dois funciona: troque
///   [_devHost] pelo IP da máquina na rede local (ex.: 192.168.x.x)
///   ou pela URL de um ambiente publicado.
class ApiConfig {
  static const _devHost = 'localhost';
  // Porta do backend (server.port no application.yml) — mudou de
  // 8080 pra 8081 na branch TG-11-filtro-pontos-cobertura. Se mudar
  // de novo, é só ajustar aqui.
  static const _devPort = 8081;

  static String get baseUrl {
    if (kIsWeb) return 'http://$_devHost:$_devPort/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_devPort/api/v1';
    }
    return 'http://$_devHost:$_devPort/api/v1';
  }
}

/// Cliente HTTP único e compartilhado por toda a API — login, troca
/// de senha, gestão de usuários e futuramente o resto passam todos
/// por aqui. Mantém o token JWT em memória (setado pelo [AuthService]
/// depois do login ou ao restaurar sessão) e injeta o header
/// Authorization automaticamente em toda chamada autenticada.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;

  void setToken(String? token) => _token = token;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// POST que espera um corpo JSON de resposta (ex.: login, criar usuário).
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final response = await http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decodeOrThrow(response);
  }

  /// POST que espera resposta em texto puro (ex.: change-password,
  /// que hoje devolve só uma string de sucesso).
  Future<String> postRaw(String path, Map<String, dynamic> body) async {
    final response = await http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    if (_isSuccess(response.statusCode)) return response.body;
    throw _errorFrom(response);
  }

  /// GET que devolve o JSON decodificado como veio (Map ou List) — ex.:
  /// GET /users devolve uma List, ao contrário de [postJson] que sempre
  /// espera um Map.
  Future<dynamic> getJson(String path) async {
    final response = await http.get(_uri(path), headers: _headers);
    if (_isSuccess(response.statusCode)) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw _errorFrom(response);
  }

  /// DELETE sem corpo de resposta esperado (204 No Content), ex.:
  /// DELETE /users/{id}.
  Future<void> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    if (!_isSuccess(response.statusCode)) throw _errorFrom(response);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (_isSuccess(response.statusCode)) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _errorFrom(response);
  }

  /// TODO: confirmar o formato real assim que o StandardError /
  /// GlobalExceptionHandler do backend forem compartilhados — hoje
  /// assume um corpo `{"message": "..."}` (ou string pura) e cai
  /// para uma mensagem genérica se o corpo não bater com isso.
  ApiException _errorFrom(http.Response response) {
    String message = 'Erro inesperado (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded is String && decoded.isNotEmpty) {
        message = decoded;
      }
    } catch (_) {
      // Corpo vazio ou não-JSON: mantém a mensagem genérica.
    }
    return ApiException(response.statusCode, message);
  }
}