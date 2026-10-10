import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/selected_area.dart';

class MapAreasController extends ChangeNotifier {
  final List<SelectedArea> _areas = [];

  int? _selecionada;

  int _versao = 0;

  int? _areaEmFoco;
  int _pedidoFoco = 0;

  List<SelectedArea> get areas => List.unmodifiable(_areas);
  bool get isEmpty => _areas.isEmpty;
  int? get selecionada => _selecionada;
  int get versao => _versao;

  Map<String, dynamic>? get geoJson => SelectedArea.toGeoJson(_areas);
  int? get areaEmFoco => _areaEmFoco;
  int get pedidoFoco => _pedidoFoco;

  bool contemPonto(LatLng p) => _areas.any((a) => a.contains(p));

  int? indiceEm(LatLng p) {
    for (var i = _areas.length - 1; i >= 0; i--) {
      if (_areas[i].contains(p)) return i;
    }
    return null;
  }

  void adicionar(SelectedArea area) {
    _areas.add(area);
    _versao++;
    notifyListeners();
  }

  void remover(int i) {
    if (i < 0 || i >= _areas.length) return;
    _areas.removeAt(i);
    _versao++;
    _areaEmFoco = null;
    final s = _selecionada;
    if (s == i) {
      _selecionada = null;
    } else if (s != null && s > i) {
      _selecionada = s - 1;
    }
    notifyListeners();
  }

  void removerSelecionada() {
    final s = _selecionada;
    if (s != null) remover(s);
  }

  void limpar() {
    if (_areas.isEmpty) return;
    _areas.clear();
    _versao++;
    _areaEmFoco = null;
    _selecionada = null;
    notifyListeners();
  }

  void selecionar(int? i) {
    if (i != null && (i < 0 || i >= _areas.length)) return;
    if (_selecionada == i) return;
    _selecionada = i;
    notifyListeners();
  }

  void focar(int i) {
    if (i < 0 || i >= _areas.length) return;
    _selecionada = i;
    _areaEmFoco = i;
    _pedidoFoco++;
    notifyListeners();
  }
}