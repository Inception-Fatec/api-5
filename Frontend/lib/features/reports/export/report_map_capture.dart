import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';

/// Tira uma "foto" do mapa do relatório (mancha, pontos, gateways e mapa
/// base) em PNG, para o PDF.
///
/// Monta um [ReportMap] fora da tela (quase transparente, sem receber
/// toque) numa camada do Overlay, espera os tiles do mapa carregarem
/// ([settle]) e captura com [RepaintBoundary]. Devolve null se algo falhar
/// (sem Overlay, erro de captura): o PDF sai sem a imagem.
///
/// Não há como saber quando o último tile chegou; [settle] é um tempo de
/// espera. Com rede lenta o fundo do mapa pode sair incompleto (a mancha e
/// os pontos saem sempre).
Future<Uint8List?> captureReportMap(
  BuildContext context,
  CoverageReport report, {
  Size size = const Size(800, 560),
  double pixelRatio = 2,
  Duration settle = const Duration(milliseconds: 3500),
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;

  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          // Quase invisível, mas ainda pintado (opacidade 0 não pinta).
          opacity: 0.01,
          child: Material(
            type: MaterialType.transparency,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ReportMap(
                  report: report,
                  interactive: false,
                  gatewayMarkers: GatewayMarkerMode.pins,
                  fitPadding: ReportStyles.captureFitPadding,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  try {
    overlay.insert(entry);
    await Future<void>.delayed(settle);
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}
