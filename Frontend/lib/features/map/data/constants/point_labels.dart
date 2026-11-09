/// Rótulos de exibição dos dados de um ponto (detalhe do ponto).
class PointLabels {
  PointLabels._();

  /// Campos mostrados no detalhe, na ordem de exibição. `nome` fica de
  /// fora da lista (já aparece no cabeçalho).
  static const fields = {
    'mun': 'Município (IBGE)',
    'brr': 'Bairro',
    'sub': 'Subestação',
    'conj': 'Conjunto Elétrico',
    'clas_sub': 'Classe / Subclasse',
    'cnae': 'CNAE',
    'car_inst': 'Carga Instalada (kW)',
    'dem_cont': 'Demanda Contratada (kW)',
    'tip_sist': 'Tipo de Sistema',
    'are_loc': 'Área de Localização',
    'uni_tr_mt': 'Transformador MT',
    'dist': 'Distribuidora (código)',
  };

  static const layers = {
    'ALTO': 'Alta Tensão',
    'MEDIO': 'Média Tensão',
    'BAIXO': 'Baixa Tensão',
    'SUB': 'Subestação',
  };

  static String layerLabel(String layer) => layers[layer] ?? layer;
}
