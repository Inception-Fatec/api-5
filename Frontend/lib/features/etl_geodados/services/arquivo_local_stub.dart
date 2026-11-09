import 'arquivo_local.dart';

/// Fora da web o upload continua pelo caminho do arquivo (dart:io); estas
/// funções só existem no navegador.
const bool envioPeloNavegador = false;

Future<ArquivoLocal?> escolherZipNoNavegador() =>
    throw UnsupportedError('Disponível só na web.');

void prepararArquivosSoltos() {}

Future<ArquivoLocal> arquivoDeUrlBlob(String url, String nome) =>
    throw UnsupportedError('Disponível só na web.');

Future<RespostaEnvio> enviarPeloNavegador({
  required ArquivoLocal arquivo,
  required Uri uri,
  required Map<String, String> campos,
  String? token,
  required void Function(double progresso) onProgress,
}) =>
    throw UnsupportedError('Disponível só na web.');
