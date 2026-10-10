/// Opções fixas dos filtros do mapa de pontos.
class MapFilterOptions {
  MapFilterOptions._();

  /// Valores enviados ao backend em `target_layers`.
  static const targetLayers = ['alto', 'medio', 'baixo', 'all'];

  /// "Todos" já vem marcado ao abrir o mapa.
  static const defaultTargetLayers = ['all'];

  /// Rótulo de exibição de um valor de [targetLayers].
  static String targetLayerLabel(String valor) => switch (valor) {
        'alto' => 'Alto',
        'medio' => 'Médio',
        'baixo' => 'Baixo',
        'all' => 'Todos',
        _ => valor,
      };

  /// Separador entre código e descrição nos rótulos de [clasSub].
  static const clasSubSeparator = ' — ';

  /// Códigos reais de CLAS_SUB confirmados no banco. Os prefixos
  /// CO/PP/RU/SP seguem o dicionário do cliente (Grupo B: IN=Industrial,
  /// CO*=Comercial, RU*=Rural, PP*=Poder Público, SP*=Serviço Público);
  /// IP e CPR não têm significado confirmado e ficam como código puro.
  static const clasSub = [
    'IN — Industrial',
    'CO1 — Comercial',
    'CO4 — Comercial',
    'CO5 — Comercial',
    'CO6 — Comercial',
    'CO8 — Comercial',
    'PP1 — Poder Público',
    'PP2 — Poder Público',
    'PP3 — Poder Público',
    'RU1 — Rural',
    'RU2 — Rural',
    'RU5 — Rural',
    'SP2 — Serviço Público',
    'IP',
    'CPR',
  ];

  /// Código enviado ao backend a partir do rótulo ("CO1 — Comercial" → "CO1").
  static String clasSubCode(String rotulo) =>
      rotulo.split(clasSubSeparator).first;
}
