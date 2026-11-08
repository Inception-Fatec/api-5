/// Fonte única de verdade para o mapeamento código → nome de
/// distribuidora. Usada no popup "Novo Projeto", no card de projeto e
/// no relatório — nunca deve ser duplicada à mão em outro lugar (regra
/// de paridade/fonte única do projeto).
///
/// Os nomes vêm do backend (GET /distribuidoras) e são registrados por
/// [registrarDistribuidoras]; [kDistribuidoras] é só o reserva para
/// quando a lista ainda não foi carregada.
library;

const Map<String, String> kDistribuidoras = {
  '391': 'EDP São Paulo',
};

final Map<String, String> _carregadas = {};

/// Guarda os nomes que vieram do backend (código → nome).
void registrarDistribuidoras(Map<String, String> nomes) {
  nomes.forEach((codigo, nome) {
    if (nome.trim().isNotEmpty) _carregadas[codigo] = nome.trim();
  });
}

/// Nome de exibição da distribuidora a partir do código. Se o código
/// não estiver mapeado, cai pro próprio código como fallback seguro
/// (nunca string vazia).
String nomeDistribuidora(String distCode) =>
    _carregadas[distCode] ?? kDistribuidoras[distCode] ?? distCode;

/// Rótulo "Nome (código)" usado nos seletores e chips de distribuidora.
String rotuloDistribuidora(String distCode) =>
    '${nomeDistribuidora(distCode)} ($distCode)';
