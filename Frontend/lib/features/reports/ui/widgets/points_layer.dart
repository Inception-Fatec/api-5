import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';

/// Projeta uma [PointCloud] para coordenadas de tela, descartando o que
/// está fora da área visível. Lógica pura (sem Flutter) para testar.
///
/// Usa Web Mercator com tile de 256 px (o padrão do `TileLayer` do
/// flutter_map): `escala = 256 * 2^zoom` pixels para o mundo todo.
class PointsProjector {
  PointsProjector._();

  static const tileSize = 256.0;

  /// Escreve em [out] os pares (x, y) dos pontos visíveis e devolve
  /// quantos pontos foram escritos. [out] precisa ter, no mínimo,
  /// `cloud.unitXY.length` posições. Sem rotação de mapa.
  static int project({
    required Float64List unitXY,
    required double centerUnitX,
    required double centerUnitY,
    required double zoom,
    required Size size,
    required Float32List out,
    double margin = 8,
  }) {
    final scale = tileSize * math.pow(2, zoom);
    final halfW = size.width / 2;
    final halfH = size.height / 2;

    // Caixa visível em coordenadas unitárias (com folga de [margin] px).
    final minX = centerUnitX - (halfW + margin) / scale;
    final maxX = centerUnitX + (halfW + margin) / scale;
    final minY = centerUnitY - (halfH + margin) / scale;
    final maxY = centerUnitY + (halfH + margin) / scale;

    var n = 0;
    for (var i = 0; i < unitXY.length; i += 2) {
      final x = unitXY[i];
      final y = unitXY[i + 1];
      if (x < minX || x > maxX || y < minY || y > maxY) continue;
      out[n++] = (x - centerUnitX) * scale + halfW;
      out[n++] = (y - centerUnitY) * scale + halfH;
    }
    return n ~/ 2;
  }

  /// Metros por pixel na latitude [latitude] (graus) e zoom [zoom].
  static double metersPerPixel(double latitude, double zoom) =>
      156543.03392 * math.cos(latitude * math.pi / 180.0).abs() /
      math.pow(2, zoom);
}

/// Camada do flutter_map que desenha a mancha de cobertura e TODOS os
/// pontos direto no canvas.
///
/// A mancha é a união de um "pincel" redondo (raio [stainRadiusM], em
/// metros) em cada ponto atendido, pintado opaco numa camada única com
/// transparência: sobreposições não escurecem e o resultado é uma área
/// contínua que segue onde há cobertura de verdade (relevo incluído),
/// em vez de um círculo do alcance.
///
/// Por que não `MarkerLayer`/cluster: cada marker é um widget; com
/// centenas de milhares de pontos isso trava. Aqui um `Float32List`
/// reaproveitado é projetado a cada frame e desenhado com
/// `drawRawPoints`. Só desenha o que está na tela.
class PointsLayer extends StatefulWidget {
  const PointsLayer({
    super.key,
    required this.covered,
    required this.uncovered,
    required this.stainRadiusM,
  });

  final PointCloud covered;
  final PointCloud uncovered;

  /// Raio do pincel da mancha, em metros.
  final double stainRadiusM;

  @override
  State<PointsLayer> createState() => _PointsLayerState();
}

class _PointsLayerState extends State<PointsLayer> {
  late Float32List _coveredBuffer;
  late Float32List _uncoveredBuffer;

  @override
  void initState() {
    super.initState();
    _allocate();
  }

  @override
  void didUpdateWidget(covariant PointsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.covered, widget.covered) ||
        !identical(oldWidget.uncovered, widget.uncovered)) {
      _allocate();
    }
  }

  void _allocate() {
    _coveredBuffer = Float32List(widget.covered.unitXY.length);
    _uncoveredBuffer = Float32List(widget.uncovered.unitXY.length);
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _PointsPainter(
            covered: widget.covered,
            uncovered: widget.uncovered,
            coveredBuffer: _coveredBuffer,
            uncoveredBuffer: _uncoveredBuffer,
            stainRadiusM: widget.stainRadiusM,
            centerUnitX: PointCloud.unitX(camera.center.longitude),
            centerUnitY: PointCloud.unitY(camera.center.latitude),
            zoom: camera.zoom,
          ),
        ),
      ),
    );
  }
}

class _PointsPainter extends CustomPainter {
  _PointsPainter({
    required this.covered,
    required this.uncovered,
    required this.coveredBuffer,
    required this.uncoveredBuffer,
    required this.stainRadiusM,
    required this.centerUnitX,
    required this.centerUnitY,
    required this.zoom,
  });

  final PointCloud covered;
  final PointCloud uncovered;
  final Float32List coveredBuffer;
  final Float32List uncoveredBuffer;
  final double stainRadiusM;
  final double centerUnitX;
  final double centerUnitY;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStain(canvas, size);
    final stroke = ReportStyles.pointSize(zoom);
    if (zoom >= ReportStyles.coveredDotsMinZoom) {
      _draw(canvas, size, covered, coveredBuffer,
          ReportStyles.coveredPointColor, stroke);
    }
    // Descobertos por cima: são os que o engenheiro precisa enxergar.
    // Halo branco: o ponto vermelho continua visível sobre a mancha.
    _draw(canvas, size, uncovered, uncoveredBuffer, Colors.white, stroke + 4);
    _draw(canvas, size, uncovered, uncoveredBuffer,
        ReportStyles.uncoveredPointColor, stroke + 1);
  }

  void _paintStain(Canvas canvas, Size size) {
    if (covered.isEmpty) return;
    final mPerPx = PointsProjector.metersPerPixel(
        PointCloud.latFromUnitY(centerUnitY), zoom);
    final brushPx = math.max(
        ReportStyles.stainMinPx, 2 * stainRadiusM / mPerPx);
    // Folga na projeção: um ponto fora da tela ainda pinta a borda.
    final count = PointsProjector.project(
      unitXY: covered.unitXY,
      centerUnitX: centerUnitX,
      centerUnitY: centerUnitY,
      zoom: zoom,
      size: size,
      out: coveredBuffer,
      margin: brushPx / 2 + 8,
    );
    if (count == 0) return;
    // Opaco dentro da camada; a transparência é aplicada uma vez no fim.
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF).withOpacity(ReportStyles.stainOpacity),
    );
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(coveredBuffer, 0, count * 2),
      Paint()
        ..color = ReportStyles.stainColor
        ..strokeWidth = brushPx
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _draw(Canvas canvas, Size size, PointCloud cloud, Float32List buffer,
      Color color, double stroke) {
    if (cloud.isEmpty) return;
    final count = PointsProjector.project(
      unitXY: cloud.unitXY,
      centerUnitX: centerUnitX,
      centerUnitY: centerUnitY,
      zoom: zoom,
      size: size,
      out: buffer,
    );
    if (count == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(buffer, 0, count * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PointsPainter old) =>
      old.centerUnitX != centerUnitX ||
      old.centerUnitY != centerUnitY ||
      old.zoom != zoom ||
      old.stainRadiusM != stainRadiusM ||
      !identical(old.covered, covered) ||
      !identical(old.uncovered, uncovered);
}
