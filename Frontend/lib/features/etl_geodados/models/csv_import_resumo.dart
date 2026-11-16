import '../services/csv_preview.dart';
import 'leitura_json.dart';

/// Resposta de `POST /api/v1/etl/upload-csv` (#TG-89), mostrada no resumo
/// do modal de importação de pontos (#TG-90).
///
/// ```json
/// { "total": 10, "importadas": 7, "jaExistentes": 1, "rejeitadas": 2,
///   "rejeicoes": [ { "linha": 4, "id": "P03", "motivo": "..." } ] }
/// ```
class CsvImportResumo {
  const CsvImportResumo({
    required this.total,
    required this.importadas,
    required this.jaExistentes,
    required this.rejeitadas,
    required this.rejeicoes,
    this.rejeicoesOmitidas = 0,
  });

  /// No histórico de cargas o backend guarda só as primeiras rejeições;
  /// aqui vem quantas ficaram de fora.
  final int rejeicoesOmitidas;

  /// Linhas de dados não vazias do arquivo.
  final int total;

  /// Pontos gravados agora.
  final int importadas;

  /// Linhas válidas cujo (distribuidora, id) já existia: ignoradas, sem
  /// alterar o ponto gravado antes.
  final int jaExistentes;

  final int rejeitadas;
  final List<CsvRejeicao> rejeicoes;

  factory CsvImportResumo.fromJson(Map<String, dynamic> json) {
    final List<CsvRejeicao> rejeicoes = <CsvRejeicao>[
      for (final Object? r in (json['rejeicoes'] as List?) ?? const <Object?>[])
        if (r is Map) CsvRejeicao.fromJson(Map<String, dynamic>.from(r)),
    ];
    return CsvImportResumo(
      total: _inteiro(json['total']),
      importadas: _inteiro(json['importadas']),
      jaExistentes: _inteiro(json['jaExistentes']),
      // Se o campo faltar, a própria lista diz quantas foram.
      rejeitadas: json['rejeitadas'] == null
          ? rejeicoes.length
          : _inteiro(json['rejeitadas']),
      rejeicoes: rejeicoes,
      rejeicoesOmitidas: _inteiro(json['rejeicoesOmitidas']),
    );
  }

  /// Nenhum ponto novo e todos os válidos já estavam no banco: o mesmo
  /// arquivo (ou os mesmos ids) já tinha sido importado para essa
  /// distribuidora.
  bool get soJaExistentes => importadas == 0 && jaExistentes > 0;

  /// "8 importadas · 0 já existentes · 2 rejeitadas (de 10 linhas)".
  String get texto => '${_plural(importadas, 'importada', 'importadas')} · '
      '$jaExistentes já ${jaExistentes == 1 ? 'existente' : 'existentes'} · '
      '${_plural(rejeitadas, 'rejeitada', 'rejeitadas')} '
      '(de ${_plural(total, 'linha', 'linhas')})';

  /// Rejeições como CSV (`linha;id;motivo`), para copiar ou baixar e
  /// corrigir o arquivo.
  String rejeicoesCsv() {
    final StringBuffer b = StringBuffer('linha;id;motivo\r\n');
    for (final CsvRejeicao r in rejeicoes) {
      b.write('${r.linha};${celulaCsv(r.id)};${celulaCsv(r.motivo)}\r\n');
    }
    return b.toString();
  }

  static String _plural(int n, String um, String varios) =>
      '$n ${n == 1 ? um : varios}';
}

/// Linha recusada pelo backend, com o motivo.
class CsvRejeicao {
  const CsvRejeicao({required this.linha, required this.id, required this.motivo});

  /// Número da linha no arquivo, contando o cabeçalho como linha 1.
  final int linha;

  /// Id lido da linha (pode vir vazio, ex.: "id vazio").
  final String id;
  final String motivo;

  factory CsvRejeicao.fromJson(Map<String, dynamic> json) => CsvRejeicao(
        linha: _inteiro(json['linha']),
        id: (json['id'] ?? '').toString(),
        motivo: (json['motivo'] ?? '').toString(),
      );
}

int _inteiro(Object? v) => jsonInt(v) ?? 0;
