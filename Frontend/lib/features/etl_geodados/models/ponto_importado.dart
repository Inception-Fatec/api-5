import '../services/csv_preview.dart';
import 'leitura_json.dart';

/// Ponto gravado por uma importação de CSV, como vem de
/// `GET /api/v1/etl/jobs/{id}/pontos` (#TG-90).
class PontoImportado {
  const PontoImportado({
    required this.id,
    required this.papel,
    required this.latitude,
    required this.longitude,
    this.descricao,
  });

  /// Id do ponto no CSV.
  final String id;

  /// `candidato`, `ponto_a_cobrir` ou `interesse`.
  final String papel;
  final double latitude;
  final double longitude;
  final String? descricao;

  factory PontoImportado.fromJson(Map<String, dynamic> json) {
    final String descricao = (json['descricao'] ?? '').toString().trim();
    return PontoImportado(
      id: (json['id'] ?? '').toString(),
      papel: (json['papel'] ?? '').toString(),
      latitude: jsonDouble(json['latitude']),
      longitude: jsonDouble(json['longitude']),
      descricao: descricao.isEmpty ? null : descricao,
    );
  }

  /// Papéis na ordem em que aparecem nos filtros.
  static const List<String> papeis = ['candidato', 'ponto_a_cobrir', 'interesse'];

  /// Nome do papel para a tela.
  static String rotuloPapel(String papel) => switch (papel) {
        'candidato' => 'Candidato a gateway',
        'ponto_a_cobrir' => 'Ponto a cobrir',
        'interesse' => 'Ponto de interesse',
        _ => papel,
      };
}

/// Pontos de uma importação: [total] conta todos; [pontos] traz no máximo
/// [limite], na ordem em que foram gravados.
class PontosDaImportacao {
  const PontosDaImportacao({required this.total, required this.limite, required this.pontos});

  final int total;
  final int limite;
  final List<PontoImportado> pontos;

  bool get cortada => pontos.length < total;

  /// Pontos no formato do CSV de importação (`id;latitude;longitude;papel;descricao`),
  /// para baixar e reaproveitar.
  String comoCsv() {
    final StringBuffer b = StringBuffer('id;latitude;longitude;papel;descricao\r\n');
    for (final PontoImportado p in pontos) {
      b.write('${celulaCsv(p.id)};${p.latitude};${p.longitude};${p.papel};${celulaCsv(p.descricao ?? '')}\r\n');
    }
    return b.toString();
  }

  factory PontosDaImportacao.fromJson(Map<String, dynamic> json) {
    final List<PontoImportado> pontos = <PontoImportado>[
      for (final Object? p in (json['pontos'] as List?) ?? const <Object?>[])
        if (p is Map) PontoImportado.fromJson(Map<String, dynamic>.from(p)),
    ];
    return PontosDaImportacao(
      total: jsonInt(json['total']) ?? pontos.length,
      limite: jsonInt(json['limite']) ?? pontos.length,
      pontos: pontos,
    );
  }
}
