import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/state/desenho_poligono.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Polígono em desenho (#TG-146), em coordenadas do mapa: acompanha o
/// arrasto e o zoom. Lados feitos em linha cheia, lado de fechamento e linha
/// até o cursor tracejados, vértices como alças (o primeiro maior, para
/// indicar onde clicar para fechar).
class PolygonDrawingLayer extends StatelessWidget {
  final DesenhoPoligono desenho;

  const PolygonDrawingLayer({super.key, required this.desenho});

  static final _tracejado = StrokePattern.dashed(
    segments: [MapStyles.selectionDash, MapStyles.selectionDashGap],
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: desenho,
      builder: (context, _) {
        final v = desenho.vertices;
        if (v.isEmpty) return const SizedBox.shrink();
        final cursor = desenho.cursor;
        const cor = MapStyles.corArea;

        return Stack(
          children: [
            if (v.length >= 3)
              PolygonLayer(polygons: [
                Polygon(
                  points: v,
                  color: cor.withOpacity(MapStyles.selectionFillOpacity * 2),
                  borderStrokeWidth: 0,
                ),
              ]),
            PolylineLayer(polylines: [
              if (v.length >= 2)
                Polyline(
                  points: v,
                  color: cor,
                  strokeWidth: MapStyles.areaSelectedBorderWidth,
                ),
              if (cursor != null)
                Polyline(
                  points: [v.last, cursor],
                  color: cor,
                  strokeWidth: MapStyles.selectionStrokeWidth,
                  pattern: _tracejado,
                ),
              if (v.length >= 3)
                Polyline(
                  points: [cursor ?? v.last, v.first],
                  color: cor.withOpacity(0.6),
                  strokeWidth: MapStyles.selectionStrokeWidth,
                  pattern: _tracejado,
                ),
            ]),
            MarkerLayer(markers: [
              for (var i = 0; i < v.length; i++)
                Marker(
                  point: v[i],
                  width: i == 0 ? _primeiro : _vertice,
                  height: i == 0 ? _primeiro : _vertice,
                  child:
                      _Alca(primeiro: i == 0, podeFechar: desenho.podeConcluir),
                ),
            ]),
          ],
        );
      },
    );
  }

  static const double _vertice = 10;
  static const double _primeiro = 16;

  /// Raio (px) em volta do primeiro vértice em que um clique fecha o polígono.
  static const double raioFechar = 12;
}

class _Alca extends StatelessWidget {
  final bool primeiro;
  final bool podeFechar;

  const _Alca({required this.primeiro, required this.podeFechar});

  @override
  Widget build(BuildContext context) {
    final destaque = primeiro && podeFechar;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: destaque ? MapStyles.corArea : AppColors.surface,
          shape: primeiro ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              primeiro ? null : const BorderRadius.all(Radius.circular(2)),
          border: Border.all(color: MapStyles.corArea, width: 2),
        ),
      ),
    );
  }
}
