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
  });

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
      total: _int(json['total']),
      importadas: _int(json['importadas']),
      jaExistentes: _int(json['jaExistentes']),
      // Se o campo faltar, a própria lista diz quantas foram.
      rejeitadas: json['rejeitadas'] == null
          ? rejeicoes.length
          : _int(json['rejeitadas']),
      rejeicoes: rejeicoes,
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
      b.write('${r.linha};${_celula(r.id)};${_celula(r.motivo)}\r\n');
    }
    return b.toString();
  }

  static String _plural(int n, String um, String varios) =>
      '$n ${n == 1 ? um : varios}';

  /// Aspas quando o texto tem `;`, aspas ou quebra de linha (os motivos do
  /// backend juntam vários erros com "; ").
  static String _celula(String s) =>
      RegExp(r'[;"\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
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
        linha: _int(json['linha']),
        id: (json['id'] ?? '').toString(),
        motivo: (json['motivo'] ?? '').toString(),
      );
}

int _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}
