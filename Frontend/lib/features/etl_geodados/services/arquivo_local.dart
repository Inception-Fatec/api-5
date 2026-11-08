import 'dart:typed_data';

export 'arquivo_local_stub.dart' if (dart.library.js_interop) 'arquivo_local_web.dart';

/// Arquivo escolhido no navegador, sem ler o conteúdo para a memória (#TG-141).
///
/// Na web o arquivo da distribuidora tem centenas de MB: carregar tudo como
/// bytes travava o envio (chegava vazio no backend). Aqui só se lê o trecho
/// necessário para validar, e o envio vai direto do disco pelo navegador.
abstract class ArquivoLocal {
  String get nome;
  int get tamanho;

  /// Bytes de [inicio] até [fim] (exclusivo), lidos só desse trecho.
  Future<Uint8List> lerTrecho(int inicio, int fim);
}

/// Resposta do envio feito pelo navegador.
class RespostaEnvio {
  const RespostaEnvio(this.status, this.corpo);
  final int status;
  final String corpo;
}
