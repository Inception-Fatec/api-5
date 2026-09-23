/// Exceção lançada pelo [ApiClient] quando o backend responde com
/// status de erro (4xx/5xx). Guarda o statusCode pra quem quiser
/// tratar casos específicos (ex.: 401 -> senha errada, 403 -> sem
/// permissão) além da mensagem já pronta pra mostrar na tela.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}