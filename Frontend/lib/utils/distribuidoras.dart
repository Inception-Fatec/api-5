/// Fonte única de verdade para o mapeamento código → nome de
/// distribuidora. Usada tanto em NewProjectScreen (Etapa 1, dropdown
/// de Empresa/Distribuidora) quanto em ProjectsScreen (nome da
/// empresa exibido no card) — nunca deve ser duplicada à mão em outro
/// lugar (regra de paridade/fonte única do projeto).
///
/// Colocar em: lib/constants/distribuidoras.dart
library;

const Map<String, String> kDistribuidoras = {
  '391': 'EDP São Paulo',
  // TODO: popular dinamicamente quando existir um endpoint de
  // distribuidoras/concessionárias no backend.
};

/// Nome de exibição da distribuidora a partir do código. Se o código
/// não estiver mapeado, cai pro próprio código como fallback seguro
/// (nunca string vazia).
String nomeDistribuidora(String distCode) => kDistribuidoras[distCode] ?? distCode;