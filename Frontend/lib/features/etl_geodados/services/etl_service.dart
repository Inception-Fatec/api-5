import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/features/auth/data/services/auth_service.dart';

import '../models/csv_import_resumo.dart';
import '../models/etl_carga.dart';
import '../models/ponto_importado.dart';
import 'arquivo_local.dart';

class EtlUploadException implements Exception {
  const EtlUploadException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// MultipartRequest que reporta o progresso real de envio (0.0 – 1.0).
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url,
      {required this.onProgress});

  final void Function(double progresso) onProgress;

  @override
  http.ByteStream finalize() {
    final http.ByteStream original = super.finalize();
    final int total = contentLength;
    int enviados = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (List<int> dados, EventSink<List<int>> sink) {
        enviados += dados.length;
        if (total > 0) onProgress(math.min(1.0, enviados / total));
        sink.add(dados);
      },
    );
    return http.ByteStream(original.transform(transformer));
  }
}

class EtlService {
  EtlService._();

  static const String uploadPath = '/etl/upload-gdb';
  static const Duration timeout = Duration(minutes: 10);
  static const String jobsPath = '/etl/jobs';
  static const String uploadCsvPath = '/etl/upload-csv';
  static const Duration csvTimeout = Duration(minutes: 2);

  static const String _falhaConexao =
      'Falha na conexão com o servidor de processamento ETL. '
      'Verifique se o backend está em execução.';

  /// Mesma regra do ApiClient: 401/403 com sessão aberta pode ser token
  /// vencido, e o AuthService decide se desloga.
  static void _verificarSessao(int status) {
    if ((status == 401 || status == 403) &&
        AuthService.instance.token != null) {
      ApiClient.instance.onUnauthorized?.call(status);
    }
  }

  /// Quantos bytes do fim do .zip (diretório central) são varridos à procura de ".gdb".
  static const int _janelaVarredura = 2 * 1024 * 1024;

  /// Validação local leve: assinatura ZIP ("PK\x03\x04") e presença de ".gdb"
  /// nos nomes das entradas. Devolve `null` se estiver OK, ou a mensagem de erro.
  static Future<String?> validarEstruturaZip(String caminho) async {
    final file = File(caminho);
    if (!await file.exists()) {
      return 'O arquivo selecionado não foi encontrado.';
    }

    final int tamanho = await file.length();
    if (tamanho < 22) return 'O arquivo .zip está vazio ou corrompido.';

    final RandomAccessFile raf = await file.open();
    try {
      final Uint8List cabecalho = await raf.read(4);
      final bool assinaturaOk = cabecalho.length == 4 &&
          cabecalho[0] == 0x50 &&
          cabecalho[1] == 0x4B &&
          cabecalho[2] == 0x03 &&
          cabecalho[3] == 0x04;
      if (!assinaturaOk) {
        return 'O arquivo não é um .zip válido (assinatura ZIP não encontrada).';
      }

      final int janela = math.min(tamanho, _janelaVarredura);
      await raf.setPosition(tamanho - janela);
      final Uint8List cauda = await raf.read(janela);
      if (!_contemGdb(cauda)) {
        return 'O .zip não parece conter um File Geodatabase (.gdb).';
      }
      return null;
    } finally {
      await raf.close();
    }
  }

  /// Valida um arquivo escolhido no navegador lendo só o começo (assinatura
  /// ZIP) e o fim (diretório central, onde aparece o nome da pasta `.gdb`),
  /// sem carregar o arquivo inteiro na memória (#TG-141).
  static Future<String?> validarEstruturaZipArquivo(ArquivoLocal arquivo) async {
    final int tamanho = arquivo.tamanho;
    if (tamanho < 22) return 'O arquivo .zip está vazio ou corrompido.';
    final Uint8List cabecalho = await arquivo.lerTrecho(0, 4);
    final bool assinaturaOk = cabecalho.length == 4 &&
        cabecalho[0] == 0x50 &&
        cabecalho[1] == 0x4B &&
        cabecalho[2] == 0x03 &&
        cabecalho[3] == 0x04;
    if (!assinaturaOk) {
      return 'O arquivo não é um .zip válido (assinatura ZIP não encontrada).';
    }
    final int inicio = math.max(0, tamanho - _janelaVarredura);
    if (!_contemGdb(await arquivo.lerTrecho(inicio, tamanho))) {
      return 'O .zip não parece conter um File Geodatabase (.gdb).';
    }
    return null;
  }

  /// Valida a assinatura ZIP e procura a pasta `.gdb` em arquivos lidos no navegador.
  static String? validarEstruturaZipBytes(Uint8List bytes) {
    if (bytes.length < 22) return 'O arquivo .zip está vazio ou corrompido.';
    final bool assinaturaOk = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    if (!assinaturaOk) {
      return 'O arquivo não é um .zip válido (assinatura ZIP não encontrada).';
    }
    final int inicio = math.max(0, bytes.length - _janelaVarredura);
    if (!_contemGdb(Uint8List.sublistView(bytes, inicio))) {
      return 'O .zip não parece conter um File Geodatabase (.gdb).';
    }
    return null;
  }

  static bool _contemGdb(Uint8List b) {
    for (int i = 0; i + 3 < b.length; i++) {
      if (b[i] == 0x2E && // .
          (b[i + 1] | 0x20) == 0x67 && // g
          (b[i + 2] | 0x20) == 0x64 && // d
          (b[i + 3] | 0x20) == 0x62) {
        // b
        return true;
      }
    }
    return false;
  }

  /// POST multipart para o endpoint de upload-gdb do backend. Sem municípios:
  /// o backend descompacta, lê a .gdb e devolve a carga "aguardando escolha"
  /// com a distribuidora e os municípios do arquivo (#TG-143).
  static Future<EtlCarga> enviarZip({
    String? caminho,
    Uint8List? arquivoBytes,
    ArquivoLocal? arquivoNavegador,
    required String nomeArquivo,
    required void Function(double progresso) onProgress,
  }) async {
    final Uri uri = Uri.parse('${ApiConfig.baseUrl}$uploadPath');

    // Web: o navegador envia o arquivo direto do disco (sem ler para a
    // memória), com progresso real. Arquivos de centenas de MB chegavam
    // vazios quando eram lidos inteiros como bytes (#TG-141).
    if (arquivoNavegador != null) {
      final RespostaEnvio r = await enviarPeloNavegador(
        arquivo: arquivoNavegador,
        uri: uri,
        campos: const <String, String>{},
        token: AuthService.instance.token,
        onProgress: onProgress,
      );
      if (r.status == 0) throw const EtlUploadException(_falhaConexao);
      return _cargaDaResposta(r.status, _jsonDe(r.corpo),
          nomeArquivo: nomeArquivo, tamanho: arquivoNavegador.tamanho);
    }

    final request =
        _ProgressMultipartRequest('POST', uri, onProgress: onProgress);

    // O endpoint exige role ADM: sem o token o Spring responde "Access Denied".
    final String? token = AuthService.instance.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (arquivoBytes == null && caminho == null) {
      throw const EtlUploadException(
          'O arquivo selecionado não está disponível.');
    }
    request.files.add(arquivoBytes != null
        ? http.MultipartFile.fromBytes('file', arquivoBytes,
            filename: nomeArquivo)
        : await http.MultipartFile.fromPath('file', caminho!,
            filename: nomeArquivo));

    final int tamanho = arquivoBytes?.length ?? await File(caminho!).length();

    final http.Response resposta;
    try {
      final http.StreamedResponse streamed =
          await request.send().timeout(timeout);
      resposta = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const EtlUploadException(_falhaConexao);
    } on http.ClientException {
      throw const EtlUploadException(_falhaConexao);
    } on TimeoutException {
      throw const EtlUploadException(
          'O servidor ETL demorou demasiado tempo a responder.');
    }

    return _cargaDaResposta(resposta.statusCode, _tentarJson(resposta),
        nomeArquivo: nomeArquivo, tamanho: tamanho);
  }

  /// Monta a [EtlCarga] da resposta do upload ou lança o erro do backend.
  static EtlCarga _cargaDaResposta(int status, Map<String, dynamic>? json,
      {required String nomeArquivo, required int tamanho}) {
    if (status < 200 || status >= 300) {
      _verificarSessao(status);
      throw EtlUploadException(
        _mensagemDoBackend(json) ??
            'O servidor respondeu com o código HTTP $status.',
      );
    }

    final Map<String, dynamic> dados = json?['data'] is Map
        ? Map<String, dynamic>.from(json!['data'] as Map)
        : (json ?? <String, dynamic>{});

    return EtlCarga.fromJson(dados,
        nomeFallback: nomeArquivo, tamanhoFallback: tamanho);
  }

  /// Lê um arquivo pequeno do disco (o .csv escolhido ou solto fora da
  /// web; na web o arquivo vem como [ArquivoLocal]).
  static Future<Uint8List> lerArquivo(String caminho) =>
      File(caminho).readAsBytes();

  /// POST multipart de pontos externos por CSV (#TG-89 / #TG-90). Síncrono:
  /// o backend valida linha a linha e já devolve o resumo. O CSV é pequeno,
  /// então vai em bytes em todas as plataformas (inclusive na web).
  ///
  /// [client] existe para os testes; no app fica `null` (cliente padrão).
  static Future<CsvImportResumo> enviarCsv({
    required Uint8List bytes,
    required String nomeArquivo,
    required String distribuidora,
    required String municipio,
    required void Function(double progresso) onProgress,
    http.Client? client,
  }) async {
    final request = _ProgressMultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}$uploadCsvPath'),
        onProgress: onProgress)
      ..fields['distribuidora'] = distribuidora
      ..fields['municipio'] = municipio
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: nomeArquivo));

    final String? token = AuthService.instance.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final http.Response resposta;
    try {
      final http.StreamedResponse streamed =
          await (client?.send(request) ?? request.send()).timeout(csvTimeout);
      resposta = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const EtlUploadException(
          'O servidor demorou demais para responder. Tente de novo.');
    } on SocketException {
      throw const EtlUploadException(_falhaConexao);
    } on http.ClientException {
      throw const EtlUploadException(_falhaConexao);
    }
    return resumoCsvDaResposta(resposta.statusCode, _tentarJson(resposta));
  }

  /// Monta o resumo da importação ou lança o erro com a mensagem para o ADM.
  static CsvImportResumo resumoCsvDaResposta(
      int status, Map<String, dynamic>? json) {
    if (status == 403) {
      // Só desloga se o token venceu (regra do AuthService); com o token
      // válido é falta de permissão mesmo.
      _verificarSessao(status);
      throw const EtlUploadException(
          'Apenas administradores podem importar pontos.');
    }
    if (status < 200 || status >= 300) {
      _verificarSessao(status);
      // 422 (BusinessRuleException) traz o motivo em `message`, ex.:
      // "Cabeçalho inválido: faltam as colunas [papel]...".
      throw EtlUploadException(status == 401
          ? 'Sua sessão expirou. Entre novamente para importar os pontos.'
          : (_mensagemDoBackend(json) ??
              'O servidor respondeu com o código HTTP $status.'));
    }
    if (json == null) {
      throw const EtlUploadException(
          'Resposta inesperada do servidor ao importar o CSV.');
    }
    return CsvImportResumo.fromJson(json);
  }

  /// GET /api/v1/etl/jobs/{id}: devolve a carga com o status atual do processamento.
  /// Etapa 2 (#TG-143): manda os municípios escolhidos e a carga começa.
  static Future<EtlCarga> iniciarCarga(EtlCarga carga, List<String> municipios) =>
      _postJob(carga, 'iniciar', <String, Object>{
        'municipios': municipios,
        'incluirConsumidores': true,
      });

  /// Descarta um upload que aguardava a escolha dos municípios.
  static Future<EtlCarga> cancelarCarga(EtlCarga carga) => _postJob(carga, 'cancelar', null);

  static Future<EtlCarga> _postJob(EtlCarga carga, String acao, Map<String, Object>? corpo) async {
    final String? token = AuthService.instance.token;
    final http.Response resposta;
    try {
      resposta = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$jobsPath/${carga.id}/$acao'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: corpo == null ? null : jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const EtlUploadException(_falhaConexao);
    }
    return _cargaDaResposta(resposta.statusCode, _tentarJson(resposta),
        nomeArquivo: carga.nomeArquivo, tamanho: carga.tamanhoBytes);
  }

  static Future<EtlCarga> consultarCarga(EtlCarga atual) async {
    final String? token = AuthService.instance.token;
    final http.Response resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$jobsPath/${atual.id}'),
      headers: <String, String>{
        if (token != null) 'Authorization': 'Bearer $token'
      },
    ).timeout(const Duration(seconds: 30));

    _verificarSessao(resposta.statusCode);
    final Map<String, dynamic>? json = _tentarJson(resposta);
    if (resposta.statusCode < 200 ||
        resposta.statusCode >= 300 ||
        json == null) {
      throw EtlUploadException(
          'Não foi possível consultar o status (HTTP ${resposta.statusCode}).');
    }
    return EtlCarga.fromJson(json,
        nomeFallback: atual.nomeArquivo, tamanhoFallback: atual.tamanhoBytes);
  }

  /// GET /api/v1/etl/jobs: as últimas cargas gravadas no banco (de qualquer
  /// ADM), mais novas primeiro. Assim o histórico sobrevive ao F5 (#TG-141).
  static Future<List<EtlCarga>> listarCargas() async {
    final String? token = AuthService.instance.token;
    final http.Response resposta = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$jobsPath'),
      headers: <String, String>{
        if (token != null) 'Authorization': 'Bearer $token'
      },
    ).timeout(const Duration(seconds: 30));
    _verificarSessao(resposta.statusCode);
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw EtlUploadException(
          'Não foi possível carregar o histórico (HTTP ${resposta.statusCode}).');
    }
    try {
      return EtlCarga.listFromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
    } catch (_) {
      return <EtlCarga>[];
    }
  }

  /// GET /api/v1/etl/jobs/{id}/pontos: pontos gravados por uma importação de
  /// CSV do histórico (#TG-90). [client] existe para os testes.
  static Future<PontosDaImportacao> listarPontosDaImportacao(String cargaId,
      {int limite = 1000, http.Client? client}) async {
    final String? token = AuthService.instance.token;
    final http.Response resposta;
    try {
      resposta = await (client?.get ?? http.get)(
        Uri.parse('${ApiConfig.baseUrl}$jobsPath/$cargaId/pontos?limite=$limite'),
        headers: <String, String>{if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const EtlUploadException(_falhaConexao);
    }
    final Map<String, dynamic>? json = _tentarJson(resposta);
    if (resposta.statusCode < 200 || resposta.statusCode >= 300 || json == null) {
      _verificarSessao(resposta.statusCode);
      throw EtlUploadException(_mensagemDoBackend(json) ??
          'Não foi possível carregar os pontos importados (HTTP ${resposta.statusCode}).');
    }
    return PontosDaImportacao.fromJson(json);
  }

  /// Motivo do erro no corpo do backend (StandardError usa `message`).
  static String? _mensagemDoBackend(Map<String, dynamic>? json) =>
      (json?['message'] ?? json?['mensagem'] ?? json?['error'] ?? json?['detail'])?.toString();

  static Map<String, dynamic>? _tentarJson(http.Response r) {
    try {
      return _jsonDe(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _jsonDe(String corpo) {
    try {
      final Object? d = jsonDecode(corpo);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }
}
