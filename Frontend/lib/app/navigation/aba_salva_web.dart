import 'package:web/web.dart' as web;

/// sessionStorage: vale para a aba do navegador e sobrevive ao F5, mas uma
/// aba nova do navegador começa em Projetos (#TG-145).
const String _chave = 'tecsys_aba_atual';

String? lerAbaSalva() {
  try {
    return web.window.sessionStorage.getItem(_chave);
  } catch (_) {
    return null; // armazenamento bloqueado: abre em Projetos
  }
}

void salvarAba(String chave) {
  try {
    web.window.sessionStorage.setItem(_chave, chave);
  } catch (_) {}
}
