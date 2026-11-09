import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/services/points_filter_service.dart';

/// Sugestões do autocompletar de bairro: espera o usuário parar de
/// digitar e consulta os nomes reais do banco nas cidades marcadas.
class BairroSuggestionsController extends ChangeNotifier {
  BairroSuggestionsController({
    required this.munCodes,
    PointsFilterService? service,
    this.debounce = MapConfig.suggestionDebounce,
  }) : _service = service ?? PointsFilterService();

  /// Lido na hora da busca, para refletir as cidades marcadas agora.
  final List<String> Function() munCodes;
  final Duration debounce;
  final PointsFilterService _service;

  Timer? _timer;
  int _pedido = 0;
  bool _disposed = false;

  List<String> _sugestoes = [];
  bool _buscando = false;

  List<String> get sugestoes => _sugestoes;
  bool get buscando => _buscando;

  void aoDigitar(String texto) {
    _timer?.cancel();
    _pedido++; // descarta respostas de buscas anteriores
    final termo = texto.trim();
    if (termo.length < MapConfig.suggestionMinChars) {
      limpar();
      return;
    }
    _timer = Timer(debounce, () => _buscar(termo));
  }

  Future<void> _buscar(String termo) async {
    final meuPedido = _pedido;
    _buscando = true;
    notifyListeners();
    final resultado = await _service.buscarSugestoesBairro(
      munCodes: munCodes(),
      texto: termo,
    );
    if (_disposed || meuPedido != _pedido) return;
    _sugestoes = resultado;
    _buscando = false;
    notifyListeners();
  }

  void limpar() {
    _timer?.cancel();
    _pedido++;
    _sugestoes = [];
    _buscando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
