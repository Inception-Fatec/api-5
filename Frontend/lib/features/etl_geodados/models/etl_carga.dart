/// Estado de uma carga ETL.
enum EtlCargaStatus { concluido, processando, erro }

/// Tabela PostGIS carregada, com as métricas reais devolvidas pelo ETL (summary do job).
class EtlCamada {
  const EtlCamada({
    required this.nome,
    required this.naCidade,
    required this.paisForaDaArea,
    required this.gravados,
    required this.ignorados,
  });

  /// Nome da tabela (ex.: "ssdmt").
  final String nome;

  /// Registros dos municípios selecionados que passaram pelos filtros.
  final int naCidade;

  /// Subestações/transformadores fora dos municípios, gravados só para manter os vínculos da rede.
  final int paisForaDaArea;

  /// Registros inseridos no banco nesta execução.
  final int gravados;

  /// Registros ignorados (já existentes no banco ou sem transformador).
  final int ignorados;

  factory EtlCamada.fromMetricas(String nome, Map<String, dynamic> m) {
    int i(String k) => EtlCarga._asInt(m[k]) ?? 0;

    final bool consumidor = m.containsKey('retidos'); // ucat_pj / ucmt_pj
    final bool baixaTensao = m.containsKey('raw_disponiveis'); // ucbt

    final int naCidade = consumidor
        ? i('retidos')
        : baixaTensao
            ? i('raw_disponiveis')
            : i('lidos') - i('fora_municipio') - i('inativos') - i('descartados_geometria');

    return EtlCamada(
      nome: nome,
      naCidade: naCidade < 0 ? 0 : naCidade,
      paisForaDaArea: i('pais_fora_da_area'),
      gravados: i('inseridos'),
      ignorados: baixaTensao ? i('sem_transformador_ou_ja_existentes') : i('ignorados_ja_existentes'),
    );
  }
}

/// Modelo tipado de uma carga ETL (.zip).
class EtlCarga {
  const EtlCarga({
    required this.id,
    required this.nomeArquivo,
    required this.tamanhoBytes,
    this.totalCamadas = 0,
    this.status = EtlCargaStatus.concluido,
    this.duracao,
    this.executadoEm,
    this.errorMessage,
    this.camadas = const <EtlCamada>[],
  });

  final String id;
  final String nomeArquivo;
  final int tamanhoBytes;
  final int totalCamadas;
  final EtlCargaStatus status;
  final String? duracao;
  final String? executadoEm;

  /// Motivo da falha informado pelo backend (só quando o status é FAILED).
  final String? errorMessage;
  final List<EtlCamada> camadas;

  /// Total de registros gravados no banco (soma de todas as tabelas).
  int get totalGravados => camadas.fold<int>(0, (soma, c) => soma + c.gravados);

  /// Ex.: "42.8 MB".
  String get tamanhoFormatado {
    const int mb = 1024 * 1024;
    if (tamanhoBytes >= mb) return '${(tamanhoBytes / mb).toStringAsFixed(1)} MB';
    if (tamanhoBytes >= 1024) return '${(tamanhoBytes / 1024).toStringAsFixed(1)} KB';
    return '$tamanhoBytes B';
  }

  /// Ex.: "42.8 MB • 3 Camadas PostGIS".
  String get resumo {
    final partes = <String>[tamanhoFormatado];
    if (totalCamadas > 0) {
      partes.add('$totalCamadas ${totalCamadas == 1 ? 'Camada' : 'Camadas'} PostGIS');
    }
    return partes.join(' • ');
  }

  String get statusLabel {
    switch (status) {
      case EtlCargaStatus.concluido:
        return 'Concluído';
      case EtlCargaStatus.processando:
        return 'Processando';
      case EtlCargaStatus.erro:
        return 'Falhou';
    }
  }

  /// Conversão tolerante a nomes de chaves (camelCase / snake_case / inglês).
  factory EtlCarga.fromJson(
    Map<String, dynamic> json, {
    String? nomeFallback,
    int? tamanhoFallback,
  }) {
    final Map<String, dynamic> summary = _mapa(json['summary']);
    final List<EtlCamada> camadas = <EtlCamada>[
      ..._camadasDe(_mapa(summary['geodatabase'])),
      ..._camadasDe(_mapa(summary['consumidores'])),
    ];
    final int totalCamadas = camadas.length;

    return EtlCarga(
      id: primeiro(json, const ['id', 'cargaId', 'carga_id'])?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      nomeArquivo: primeiro(json, const ['nomeArquivo', 'nome_arquivo', 'originalFilename', 'filename', 'fileName', 'name'])
              ?.toString() ??
          nomeFallback ??
          'arquivo.zip',
      tamanhoBytes: _asInt(primeiro(json, const ['tamanhoBytes', 'tamanho_bytes', 'tamanho', 'size', 'sizeBytes'])) ??
          tamanhoFallback ??
          0,
      totalCamadas: totalCamadas,
      status: _parseStatus(primeiro(json, const ['status', 'estado'])?.toString()),
      duracao: _duracao(json['startedAt'], json['finishedAt']),
      executadoEm: _formatarData(primeiro(json, const ['executadoEm', 'executado_em', 'timestamp', 'createdAt'])),
      errorMessage: primeiro(json, const ['errorMessage', 'error_message'])?.toString(),
      camadas: camadas,
    );
  }

  /// Converte qualquer resposta de lista em `List<EtlCarga>` com segurança de tipos.
  static List<EtlCarga> listFromJson(Object? raw) {
    if (raw is! List) return <EtlCarga>[];
    return raw
        .whereType<Map>()
        .map((m) => EtlCarga.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Map<String, dynamic> _mapa(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Uma camada por tabela do resumo (summary.<bloco>.tabelas) devolvido pelo ETL.
  static List<EtlCamada> _camadasDe(Map<String, dynamic> bloco) {
    final Map<String, dynamic> tabelas = _mapa(bloco['tabelas']);
    return <EtlCamada>[
      for (final MapEntry<String, dynamic> e in tabelas.entries) EtlCamada.fromMetricas(e.key, _mapa(e.value)),
    ];
  }

  /// startedAt/finishedAt (ISO-8601) -> "1 min 35 s". Nulo enquanto o job não terminou.
  static String? _duracao(Object? inicio, Object? fim) {
    final DateTime? a = inicio == null ? null : DateTime.tryParse(inicio.toString());
    final DateTime? b = fim == null ? null : DateTime.tryParse(fim.toString());
    if (a == null || b == null) return null;
    final Duration d = b.difference(a);
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    if (d.inMinutes < 60) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  static Object? primeiro(Map<String, dynamic> json, List<String> chaves) {
    for (final k in chaves) {
      if (json[k] != null) return json[k];
    }
    return null;
  }

  /// 128450 -> "128.450".
  static String milhar(int n) {
    final String s = n.abs().toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return n < 0 ? '-$b' : b.toString();
  }

  /// Data ISO-8601 do backend -> "23/10/2026 às 18:32" (horário local).
  static String? _formatarData(Object? v) {
    if (v == null) return null;
    final DateTime? d = DateTime.tryParse(v.toString())?.toLocal();
    if (d == null) return v.toString();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} às ${p(d.hour)}:${p(d.minute)}';
  }

  static int? _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static EtlCargaStatus _parseStatus(String? s) {
    final v = (s ?? '').toLowerCase();
    if (v.isEmpty) return EtlCargaStatus.processando;
    if (v.contains('conclu') || v.contains('success') || v.contains('done') || v.contains('ok')) {
      return EtlCargaStatus.concluido;
    }
    if (v.contains('process') || v.contains('pend') || v.contains('run') || v.contains('queue')) {
      return EtlCargaStatus.processando;
    }
    return EtlCargaStatus.erro;
  }
}