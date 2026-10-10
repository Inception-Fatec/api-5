import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/novo_projeto_resultado.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Estado do popup "Novo Projeto": cidades com dado, as marcadas, o erro
/// de validação e a montagem do resultado.
class NewProjectDialogController extends ChangeNotifier {
  NewProjectDialogController({IbgeService? ibgeService})
      : _ibge = ibgeService ?? IbgeService();

  /// Por enquanto só há dados da EDP São Paulo.
  static const distCode = '391';

  final IbgeService _ibge;
  bool _disposed = false;

  List<Municipio>? _cidadesDisponiveis;
  final Set<Municipio> _cidadesSelecionadas = {};
  String? _erro;
  bool _carregando = true;

  /// Null enquanto carrega ou se o carregamento falhou.
  List<Municipio>? get cidadesDisponiveis => _cidadesDisponiveis;
  Set<Municipio> get cidadesSelecionadas => _cidadesSelecionadas;
  String? get erro => _erro;
  bool get carregando => _carregando;

  String get distribuidoraLabel => rotuloDistribuidora(distCode);

  Future<void> carregarCidades() async {
    try {
      final cidades = await _ibge.buscarCidadesComDados();
      if (_disposed) return;
      _cidadesDisponiveis = cidades;
      // A primeira cidade (São José dos Campos) já vem marcada.
      if (cidades.isNotEmpty) _cidadesSelecionadas.add(cidades.first);
    } catch (_) {
      if (_disposed) return;
      _erro = 'Não foi possível carregar as cidades agora.';
    }
    _carregando = false;
    notifyListeners();
  }

  void marcarCidade(Municipio cidade, {required bool marcada}) {
    if (marcada) {
      _cidadesSelecionadas.add(cidade);
    } else {
      _cidadesSelecionadas.remove(cidade);
    }
    notifyListeners();
  }

  /// Valida e monta o resultado; devolve null (e preenche [erro]) se
  /// faltar o nome ou nenhuma cidade estiver marcada.
  NovoProjetoResultado? confirmar(String nomeDigitado) {
    final nome = nomeDigitado.trim();
    if (nome.isEmpty) {
      _erro = 'Preenche o Nome do Projeto.';
      notifyListeners();
      return null;
    }
    if (_cidadesSelecionadas.isEmpty) {
      _erro = 'Escolhe ao menos uma cidade.';
      notifyListeners();
      return null;
    }
    return NovoProjetoResultado(
      nome: nome,
      distCode: distCode,
      distribuidoraLabel: distribuidoraLabel,
      municipios: _cidadesSelecionadas.toList(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
