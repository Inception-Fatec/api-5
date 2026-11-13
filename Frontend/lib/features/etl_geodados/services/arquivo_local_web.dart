import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'arquivo_local.dart';

/// No navegador o envio é feito pelo próprio XMLHttpRequest com FormData:
/// o arquivo sai direto do disco, sem passar pela memória do app.
const bool envioPeloNavegador = true;

class _ArquivoNavegador implements ArquivoLocal {
  _ArquivoNavegador(this.blob, this.nome);

  final web.Blob blob;

  @override
  final String nome;

  @override
  int get tamanho => blob.size;

  @override
  Future<Uint8List> lerTrecho(int inicio, int fim) async {
    final web.Blob trecho = blob.slice(inicio, fim);
    final JSArrayBuffer buffer = await trecho.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}

/// Abre o seletor de arquivos do navegador. [aceitos] filtra as extensões
/// (ex.: `.zip,.csv`, #TG-90). Null se cancelar.
Future<ArquivoLocal?> escolherArquivoNoNavegador({String aceitos = '.zip'}) {
  final completer = Completer<ArquivoLocal?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = aceitos;

  void concluir(ArquivoLocal? arquivo) {
    if (!completer.isCompleted) completer.complete(arquivo);
    input.remove();
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final web.File? file = input.files?.item(0);
      concluir(file == null ? null : _ArquivoNavegador(file, file.name));
    }.toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => concluir(null)).toJS);
  input.style.display = 'none';
  web.document.body?.append(input);
  input.click();
  return completer.future;
}

/// Arquivos do último "soltar" no navegador, pelo nome (#TG-141).
final Map<String, web.File> _soltos = <String, web.File>{};
bool _ouvindoSoltos = false;

/// Chamado a cada "soltar" na janela com os arquivos que o navegador
/// entregou; lista vazia quando não veio arquivo nenhum (#TG-90).
///
/// O desktop_drop falha em silêncio quando o item solto não é um arquivo
/// (ex.: arrastar do painel de downloads do Opera, que entrega só um link):
/// `webkitGetAsEntry()` volta null e o DropDone nunca chega. Por isso o
/// modal recebe o arquivo direto do evento do navegador.
void Function(List<ArquivoLocal> arquivos)? aoSoltarNoNavegador;

/// Escuta o evento `drop` da janela antes do desktop_drop (fase de captura)
/// e guarda os `File` originais: assim o arquivo solto é enviado direto do
/// disco, como no seletor, sem depender de reler a URL `blob:`.
void prepararArquivosSoltos() {
  if (_ouvindoSoltos) return;
  _ouvindoSoltos = true;
  web.window.addEventListener(
    'drop',
    (web.DragEvent e) {
      final web.FileList? files = e.dataTransfer?.files;
      _soltos.clear();
      final List<ArquivoLocal> arquivos = <ArquivoLocal>[];
      for (int i = 0; i < (files?.length ?? 0); i++) {
        final web.File? f = files!.item(i);
        if (f == null) continue;
        _soltos[f.name] = f;
        arquivos.add(_ArquivoNavegador(f, f.name));
      }
      aoSoltarNoNavegador?.call(arquivos);
    }.toJS,
    true.toJS,
  );
}

/// Arquivo solto na área de upload. Usa o `File` guardado no drop; se não
/// houver, lê pela URL `blob:` que o desktop_drop entrega.
Future<ArquivoLocal> arquivoDeUrlBlob(String url, String nome) {
  final web.File? solto = _soltos.remove(nome);
  if (solto != null) return Future.value(_ArquivoNavegador(solto, nome));
  final completer = Completer<ArquivoLocal>();
  final xhr = web.XMLHttpRequest()
    ..open('GET', url)
    ..responseType = 'blob';
  xhr.addEventListener(
    'load',
    (web.Event _) {
      if (xhr.status != 200 || xhr.response == null) {
        completer.completeError(StateError('Não foi possível ler o arquivo solto.'));
        return;
      }
      completer.complete(_ArquivoNavegador(xhr.response as web.Blob, nome));
    }.toJS,
  );
  xhr.addEventListener(
    'error',
    (web.Event _) {
      completer.completeError(StateError('Não foi possível ler o arquivo solto.'));
    }.toJS,
  );
  xhr.send();
  return completer.future;
}

/// POST multipart pelo navegador, com o arquivo indo direto do disco e o
/// progresso real do envio.
Future<RespostaEnvio> enviarPeloNavegador({
  required ArquivoLocal arquivo,
  required Uri uri,
  required Map<String, String> campos,
  String? token,
  required void Function(double progresso) onProgress,
}) {
  final completer = Completer<RespostaEnvio>();
  final form = web.FormData();
  form.append('file', (arquivo as _ArquivoNavegador).blob, arquivo.nome);
  campos.forEach((nome, valor) => form.append(nome, valor.toJS));

  final xhr = web.XMLHttpRequest()..open('POST', uri.toString());
  if (token != null) xhr.setRequestHeader('Authorization', 'Bearer $token');

  xhr.upload.addEventListener(
    'progress',
    (web.ProgressEvent e) {
      if (e.lengthComputable && e.total > 0) onProgress(e.loaded / e.total);
    }.toJS,
  );
  xhr.addEventListener(
    'load',
    (web.Event _) {
      completer.complete(RespostaEnvio(xhr.status, xhr.responseText));
    }.toJS,
  );
  xhr.addEventListener(
    'error',
    (web.Event _) {
      if (!completer.isCompleted) completer.complete(const RespostaEnvio(0, ''));
    }.toJS,
  );
  xhr.send(form);
  return completer.future;
}
