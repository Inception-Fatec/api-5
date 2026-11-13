import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: cria um Blob e clica numa âncora com `download`, que o navegador
/// trata como download (vai para a pasta padrão ou pergunta onde salvar).
Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  String mime = 'text/csv',
}) async {
  final web.Blob blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mime;charset=utf-8'),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement ancora =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = nome;
  ancora.style.display = 'none';
  web.document.body?.append(ancora);
  ancora.click();
  ancora.remove();
  // Alguns navegadores só leem o Blob depois do clique: libera a URL depois.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return true;
}
