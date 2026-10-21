/// Estado de uma carga ETL.
enum EtlCargaStatus { concluido, processando, erro }

/// Camada (tabela PostGIS) extraída de uma carga.
class EtlCamada {
  const EtlCamada({
    required this.nome,
    required this.tipo,
    required this.registros,
    this.valida = true,
  });

  final String nome;

  /// Ex.: Point, Polygon, MultiLineString.
  final String tipo;

  /// Já formatado, ex.: "45.120".
  final String registros;
  final bool valida;

  factory EtlCamada.fromJson(Map<String, dynamic> json) {
    final Object? reg = EtlCarga.primeiro(json, const ['registros', 'records', 'count', 'total']);
    return EtlCamada(
      nome: EtlCarga.primeiro(json, const ['nome', 'name', 'tabela', 'layer'])?.toString() ?? '-',
      tipo: EtlCarga.primeiro(json, const ['tipo', 'type', 'geometria', 'geometryType'])?.toString() ?? '-',
      registros: reg is num ? EtlCarga.milhar(reg.toInt()) : (reg?.toString() ?? '-'),
      valida: json['valida'] != false && json['valid'] != false,
    );
  }
}

/// Modelo tipado de uma carga ETL (.zip).
///
/// Todas as listas da UI são `List<EtlCarga>`. Nunca faças `as List<EtlCarga>`
/// sobre dados vindos de JSON: usa [EtlCarga.listFromJson], que converte cada
/// item individualmente (é isto que elimina o erro
/// `List<Map<String, dynamic>> is not a subtype of List<EtlCarga>`).
class EtlCarga {
  const EtlCarga({
    required this.id,
    required this.nomeArquivo,
    required this.tamanhoBytes,
    this.motor = 'Geodatabase Esri v10.8',
    this.totalCamadas = 0,
    this.status = EtlCargaStatus.concluido,
    this.duracao,
    this.srid,
    this.sridCurto,
    this.totalFeicoes,
    this.executadoEm,
    this.camadas = const <EtlCamada>[],
  });

  final String id;
  final String nomeArquivo;
  final int tamanhoBytes;
  final String motor;
  final int totalCamadas;
  final EtlCargaStatus status;
  final String? duracao;
  final String? srid;
  final String? sridCurto;
  final String? totalFeicoes;
  final String? executadoEm;
  final List<EtlCamada> camadas;

  /// Ex.: "42.8 MB".
  String get tamanhoFormatado {
    const int mb = 1024 * 1024;
    if (tamanhoBytes >= mb) return '${(tamanhoBytes / mb).toStringAsFixed(1)} MB';
    if (tamanhoBytes >= 1024) return '${(tamanhoBytes / 1024).toStringAsFixed(1)} KB';
    return '$tamanhoBytes B';
  }

  /// Ex.: "42.8 MB • Geodatabase Esri v10.8 • 3 Camadas PostGIS".
  String get resumo {
    final partes = <String>[tamanhoFormatado, motor];
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
    final Object? camadasRaw =
        primeiro(json, const ['camadas', 'layers', 'totalCamadas', 'total_camadas', 'layersCount']);
    final List<EtlCamada> camadas = camadasRaw is List
        ? camadasRaw
            .whereType<Map>()
            .map((m) => EtlCamada.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <EtlCamada>[];
    final int totalCamadas = camadasRaw is List ? camadasRaw.length : _asInt(camadasRaw) ?? 0;

    final Object? feicoes = primeiro(json, const ['totalFeicoes', 'total_feicoes', 'featuresCount', 'features']);
    final String? sridCurto = primeiro(json, const ['sridCurto', 'sridShort'])?.toString();
    final String? srid = primeiro(json, const ['srid', 'projecao'])?.toString();

    return EtlCarga(
      id: primeiro(json, const ['id', 'cargaId', 'carga_id'])?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      nomeArquivo: primeiro(json, const ['nomeArquivo', 'nome_arquivo', 'filename', 'fileName', 'name'])
              ?.toString() ??
          nomeFallback ??
          'arquivo.zip',
      tamanhoBytes: _asInt(primeiro(json, const ['tamanhoBytes', 'tamanho_bytes', 'tamanho', 'size', 'sizeBytes'])) ??
          tamanhoFallback ??
          0,
      motor: primeiro(json, const ['motor', 'engine'])?.toString() ?? 'Geodatabase Esri v10.8',
      totalCamadas: totalCamadas,
      status: _parseStatus(primeiro(json, const ['status', 'estado'])?.toString()),
      duracao: primeiro(json, const ['duracao', 'duration', 'tempoProcessamento'])?.toString(),
      srid: srid ?? sridCurto,
      sridCurto: sridCurto ?? srid,
      totalFeicoes: feicoes is num ? milhar(feicoes.toInt()) : feicoes?.toString(),
      executadoEm: primeiro(json, const ['executadoEm', 'executado_em', 'timestamp', 'createdAt'])?.toString() ??
          _agora(),
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

  /// Dados de exemplo idênticos ao protótipo Stitch.
  static List<EtlCarga> amostras() => <EtlCarga>[
        EtlCarga(
          id: 'carga-1',
          nomeArquivo: 'rede_distribuicao_sp_sul.zip',
          tamanhoBytes: (42.8 * 1024 * 1024).round(),
          totalCamadas: 3,
          duracao: '42 segundos',
          srid: 'SIRGAS 2000 (EPSG:4674)',
          sridCurto: 'EPSG:4674',
          totalFeicoes: '128.450',
          executadoEm: '24/10/2024 às 14:32',
          camadas: const [
            EtlCamada(nome: 'geo_redes_alta_tensao', tipo: 'MultiLineString', registros: '45.120'),
            EtlCamada(nome: 'geo_postes_equipamentos', tipo: 'Point', registros: '78.230'),
            EtlCamada(nome: 'geo_subestacoes_poligonos', tipo: 'Polygon', registros: '5.100'),
          ],
        ),
        EtlCarga(
          id: 'carga-2',
          nomeArquivo: 'sensores_telemetria_rj.zip',
          tamanhoBytes: (18.4 * 1024 * 1024).round(),
          totalCamadas: 2,
          duracao: '18 segundos',
          srid: 'SIRGAS 2000 (EPSG:4674)',
          sridCurto: 'EPSG:4674',
          totalFeicoes: '34.820',
          executadoEm: '24/10/2024 às 11:15',
          camadas: const [
            EtlCamada(nome: 'geo_estacoes_sensores', tipo: 'Point', registros: '32.400'),
            EtlCamada(nome: 'geo_bacias_hidrograficas', tipo: 'Polygon', registros: '2.420'),
          ],
        ),
      ];

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

  static String _agora() {
    final DateTime d = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
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
