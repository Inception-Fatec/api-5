import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/selected_area.dart';

/// Resultado de um clique no mapa durante o desenho.
enum CliqueDesenho {
  /// Vértice novo adicionado.
  adicionado,

  /// O clique fechou o polígono (no primeiro vértice ou duplo clique).
  fechou,

  /// Recusado: o lado novo cruzaria um lado já desenhado.
  cruzaria,

  /// Recusado: clicou para fechar com menos de 3 vértices.
  poucosVertices,
}

/// Estado do desenho de um polígono por vértices (#TG-146): cada clique
/// adiciona um vértice; fecha clicando no primeiro, com duplo clique ou
/// pelo botão "Concluir". Não sabe nada de tela: quem chama diz se o clique
/// caiu perto do primeiro vértice ou se foi um duplo clique.
class DesenhoPoligono extends ChangeNotifier {
  final List<LatLng> _vertices = [];
  LatLng? _cursor;

  List<LatLng> get vertices => List.unmodifiable(_vertices);
  int get total => _vertices.length;
  bool get vazio => _vertices.isEmpty;
  bool get podeConcluir => _vertices.length >= SelectedArea.minVertices;

  /// Posição do mouse (linha tracejada do último vértice até ele).
  LatLng? get cursor => _cursor;

  set cursor(LatLng? p) {
    if (p == _cursor) return;
    _cursor = p;
    if (_vertices.isNotEmpty) notifyListeners();
  }

  /// Área (km²) do que já foi desenhado, fechando com o primeiro vértice.
  double? get areaKm2 => podeConcluir ? SelectedArea(_vertices).areaKm2 : null;

  /// Trata um clique em [p]. [noPrimeiro]: caiu sobre o primeiro vértice;
  /// [duplo]: segundo clique de um duplo clique no mesmo lugar.
  CliqueDesenho clicar(LatLng p,
      {bool noPrimeiro = false, bool duplo = false}) {
    if (noPrimeiro || duplo) {
      // O duplo clique já pôs um vértice no 1º clique: o 2º só fecha.
      if (!podeConcluir) return CliqueDesenho.poucosVertices;
      if (noPrimeiro &&
          SelectedArea.novoLadoCruza(_vertices, _vertices.first)) {
        return CliqueDesenho.cruzaria;
      }
      return CliqueDesenho.fechou;
    }
    if (SelectedArea.novoLadoCruza(_vertices, p)) return CliqueDesenho.cruzaria;
    _vertices.add(p);
    notifyListeners();
    return CliqueDesenho.adicionado;
  }

  void desfazer() {
    if (_vertices.isEmpty) return;
    _vertices.removeLast();
    notifyListeners();
  }

  void limpar() {
    if (_vertices.isEmpty && _cursor == null) return;
    _vertices.clear();
    _cursor = null;
    notifyListeners();
  }

  /// Fecha o polígono. Devolve null (e não limpa) se não der: menos de 3
  /// vértices ou lados que se cruzam.
  SelectedArea? concluir() {
    if (!podeConcluir) return null;
    final area = SelectedArea(_vertices);
    if (area.seCruza) return null;
    limpar();
    return area;
  }
}
