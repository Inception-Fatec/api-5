// #TG-141: histórico de cargas vindo do backend e validação do .zip lendo só
// trechos do arquivo (sem carregar o arquivo inteiro na memória).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/etl_geodados/models/etl_carga.dart';
import 'package:tecsys_app/features/etl_geodados/services/arquivo_local.dart';
import 'package:tecsys_app/features/etl_geodados/services/etl_service.dart';

/// Arquivo em memória que conta quantos bytes foram lidos.
class ArquivoFalso implements ArquivoLocal {
  ArquivoFalso(this.bytes, {this.nome = 'teste.zip'});

  final Uint8List bytes;
  int bytesLidos = 0;

  @override
  final String nome;

  @override
  int get tamanho => bytes.length;

  @override
  Future<Uint8List> lerTrecho(int inicio, int fim) async {
    bytesLidos += fim - inicio;
    return Uint8List.sublistView(bytes, inicio, fim);
  }
}

Uint8List zipFalso(int tamanho, {bool assinatura = true, bool comGdb = true}) {
  final Uint8List b = Uint8List(tamanho);
  if (assinatura) b.setAll(0, const [0x50, 0x4B, 0x03, 0x04]);
  if (comGdb) b.setAll(tamanho - 100, 'EDP_ES.gdb/'.codeUnits);
  return b;
}

void main() {
  group('EtlCarga.listFromJson (GET /etl/jobs)', () {
    test('lê tamanho, status e log da carga que falhou', () {
      final cargas = EtlCarga.listFromJson([
        {
          'id': 7,
          'status': 'FAILED',
          'originalFilename': 'EDP_ES.zip',
          'fileSizeBytes': 580911104,
          'errorMessage': 'Camada UCBT não encontrada',
          'logTail': 'linha 1\nlinha 2',
          'createdAt': '2026-11-08T12:00:00Z',
        },
        {'id': 6, 'status': 'SUCCESS', 'originalFilename': 'antigo.zip'},
      ]);

      expect(cargas, hasLength(2));
      expect(cargas[0].status, EtlCargaStatus.erro);
      expect(cargas[0].tamanhoFormatado, '554.0 MB');
      expect(cargas[0].logTail, 'linha 1\nlinha 2');
      expect(cargas[1].logTail, isNull);
    });

    test('carga antiga sem tamanho não mostra "0 B" no resumo', () {
      final carga = EtlCarga.fromJson({'id': 1, 'status': 'SUCCESS'});
      expect(carga.resumo, isNot(contains('0 B')));
    });
  });

  group('EtlService.validarEstruturaZipArquivo', () {
    test('aceita .zip com .gdb lendo só o começo e o fim do arquivo', () async {
      final arquivo = ArquivoFalso(zipFalso(8 * 1024 * 1024));
      expect(await EtlService.validarEstruturaZipArquivo(arquivo), isNull);
      expect(arquivo.bytesLidos, lessThanOrEqualTo(2 * 1024 * 1024 + 4));
    });

    test('recusa arquivo que não é .zip', () async {
      final arquivo = ArquivoFalso(zipFalso(4096, assinatura: false));
      expect(await EtlService.validarEstruturaZipArquivo(arquivo),
          contains('não é um .zip válido'));
    });

    test('recusa .zip sem File Geodatabase', () async {
      final arquivo = ArquivoFalso(zipFalso(4096, comGdb: false));
      expect(await EtlService.validarEstruturaZipArquivo(arquivo),
          contains('.gdb'));
    });
  });
}
