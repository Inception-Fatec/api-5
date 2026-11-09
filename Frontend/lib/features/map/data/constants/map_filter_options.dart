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

  /// Camadas BDGD que podem ser pontos a cobrir (#TG-92): consumidores.
  static const camadasCobertura = ['ucbt', 'ucmt_pj', 'ucat_pj'];

  /// Camadas BDGD que podem ser candidatas a gateway (#TG-92):
  /// transformadores e, se o usuário quiser, consumidores.
  static const camadasCandidatas = [
    'untrmt',
    'untrat',
    'ucbt',
    'ucmt_pj',
    'ucat_pj',
  ];

  /// Padrão do sistema: consumidores são pontos, transformadores candidatos.
  static const padraoCobertura = camadasCobertura;
  static const padraoCandidatos = ['untrmt', 'untrat'];

  /// Rótulo de uma camada BDGD nos seletores de papel.
  static String camadaLabel(String camada) => switch (camada) {
        'ucbt' => 'Consumidores de baixa tensão',
        'ucmt_pj' => 'Consumidores de média tensão',
        'ucat_pj' => 'Consumidores de alta tensão',
        'untrmt' => 'Transformadores de média tensão',
        'untrat' => 'Transformadores de alta tensão',
        _ => camada,
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

  /// Rótulo a partir do código salvo no projeto ("CO1" → "CO1 — Comercial").
  static String clasSubRotulo(String codigo) => clasSub.firstWhere(
        (r) => clasSubCode(r) == codigo,
        orElse: () => codigo,
      );
}
