/// Salva um arquivo gerado pelo app (ex.: o modelo de CSV, #TG-90).
///
/// Mesmo padrão de import condicional do `arquivo_local.dart`: na web o
/// download é feito pelo navegador (Blob + âncora); fora dela, pelo
/// diálogo "Salvar como" do file_picker.
///
/// `Future<bool> salvarArquivo({nome, bytes, mime})` devolve `false` se o
/// usuário cancelou a escolha do local.
library;

export 'salvar_arquivo_io.dart'
    if (dart.library.js_interop) 'salvar_arquivo_web.dart';
