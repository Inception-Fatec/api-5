import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
// Ajuste o caminho se o seu AuthService estiver em outra pasta.
import 'package:tecsys_app/features/auth/data/services/auth_service.dart';

import '../models/etl_carga.dart';

class EtlUploadException implements Exception {
  const EtlUploadException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// MultipartRequest que reporta o progresso real de envio (0.0 – 1.0).
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {required this.onProgress});

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

  static const String baseUrl = 'http://localhost:8081';
  static const String uploadPath = '/api/v1/etl/upload-gdb';
  static const Duration timeout = Duration(minutes: 10);
  static const String jobsPath = '/api/v1/etl/jobs';

  /// Quantos bytes do fim do .zip (diretório central) são varridos à procura de ".gdb".
  static const int _janelaVarredura = 2 * 1024 * 1024;

  /// Validação local leve: assinatura ZIP ("PK\x03\x04") e presença de ".gdb"
  /// nos nomes das entradas. Devolve `null` se estiver OK, ou a mensagem de erro.
  static Future<String?> validarEstruturaZip(String caminho) async {
    final file = File(caminho);
    if (!await file.exists()) return 'O arquivo selecionado não foi encontrado.';

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

  /// POST multipart para o endpoint de upload-gdb do backend.
  static Future<EtlCarga> enviarZip({
    required String caminho,
    required String nomeArquivo,
    required List<String> municipios, // códigos IBGE de 7 dígitos
    required void Function(double progresso) onProgress,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$uploadPath');
    final request = _ProgressMultipartRequest('POST', uri, onProgress: onProgress);

    // O endpoint exige role ADM: sem o token o Spring responde "Access Denied".
    final String? token = AuthService.instance.token;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Anexa o ficheiro com o nome do campo 'file' exigido pelo EtlController do backend
    request.files.add(await http.MultipartFile.fromPath('file', caminho, filename: nomeArquivo));
    
    // Municípios escolhidos pelo usuário (o backend só aceita códigos IBGE, separados por vírgula).
    request.fields['municipios'] = municipios.join(',');
    request.fields['incluirConsumidores'] = 'true';

    final int tamanho = await File(caminho).length();

    final http.Response resposta;
    try {
      final http.StreamedResponse streamed = await request.send().timeout(timeout);
      resposta = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const EtlUploadException(
        'Falha na conexão com o servidor de processamento ETL (localhost:8081). '
        'Verifique se o backend está em execução.',
      );
    } on http.ClientException {
      throw const EtlUploadException(
        'Falha na conexão com o servidor de processamento ETL (localhost:8081). '
        'Verifique se o backend está em execução.',
      );
    } on TimeoutException {
      throw const EtlUploadException('O servidor ETL demorou demasiado tempo a responder.');
    }

    final Map<String, dynamic>? json = _tentarJson(resposta);

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      final Object? msg = json?['message'] ?? json?['mensagem'] ?? json?['error'] ?? json?['detail'];
      throw EtlUploadException(
        msg?.toString() ?? 'O servidor respondeu com o código HTTP ${resposta.statusCode}.',
      );
    }

    final Map<String, dynamic> dados = json?['data'] is Map
        ? Map<String, dynamic>.from(json!['data'] as Map)
        : (json ?? <String, dynamic>{});

    return EtlCarga.fromJson(dados, nomeFallback: nomeArquivo, tamanhoFallback: tamanho);
  }

  /// GET /api/v1/etl/jobs/{id}: devolve a carga com o status atual do processamento.
  static Future<EtlCarga> consultarCarga(EtlCarga atual) async {
    final String? token = AuthService.instance.token;
    final http.Response resposta = await http
        .get(
          Uri.parse('$baseUrl$jobsPath/${atual.id}'),
          headers: <String, String>{if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    final Map<String, dynamic>? json = _tentarJson(resposta);
    if (resposta.statusCode < 200 || resposta.statusCode >= 300 || json == null) {
      throw EtlUploadException('Não foi possível consultar o status (HTTP ${resposta.statusCode}).');
    }
    return EtlCarga.fromJson(json, nomeFallback: atual.nomeArquivo, tamanhoFallback: atual.tamanhoBytes);
  }

  static Map<String, dynamic>? _tentarJson(http.Response r) {
    try {
      final Object? d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }
}