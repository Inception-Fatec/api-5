import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class AreaSelectionOverlay extends StatefulWidget {
  final ValueNotifier<Rect?> selecao;
  final LatLng Function(Offset ponto, Size tamanho) telaParaLatLng;
  final ValueChanged<SelectedArea> onConfirmar;

  const AreaSelectionOverlay({
    super.key,
    required this.selecao,
    required this.telaParaLatLng,
    required this.onConfirmar,
  });

  @override
  State<AreaSelectionOverlay> createState() => _AreaSelectionOverlayState();
}

class _AreaSelectionOverlayState extends State<AreaSelectionOverlay> {
  final _arrastando = ValueNotifier<bool>(false);
  Offset? _inicio;
  Size _tamanho = Size.zero;

  @override
  void dispose() {
    _arrastando.dispose();
    super.dispose();
  }

  void _aoComecar(DragStartDetails d) {
    _inicio = d.localPosition;
    _arrastando.value = true;
    widget.selecao.value = Rect.fromPoints(d.localPosition, d.localPosition);
  }

  void _aoArrastar(DragUpdateDetails d) {
    final inicio = _inicio;
    if (inicio == null) return;
    final limitado = Offset(
      d.localPosition.dx.clamp(0.0, _tamanho.width),
      d.localPosition.dy.clamp(0.0, _tamanho.height),
    );
    widget.selecao.value = Rect.fromPoints(inicio, limitado);
  }

  void _aoTerminar(DragEndDetails _) {
    _arrastando.value = false;
    final r = widget.selecao.value;
    if (r == null ||
        r.width < MapStyles.selectionMinSize ||
        r.height < MapStyles.selectionMinSize) {
      widget.selecao.value = null; // toque sem arrastar: ignora
    }
  }

  void _confirmar() {
    final r = widget.selecao.value;
    if (r == null) return;
    widget.onConfirmar(SelectedArea.fromCorners(
      widget.telaParaLatLng(r.topLeft, _tamanho),
      widget.telaParaLatLng(r.bottomRight, _tamanho),
    ));
  }

  void _descartar() => widget.selecao.value = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _tamanho = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _aoComecar,
                onPanUpdate: _aoArrastar,
                onPanEnd: _aoTerminar,
                child: const MouseRegion(cursor: SystemMouseCursors.precise),
              ),
            ),
            ValueListenableBuilder<Rect?>(
              valueListenable: widget.selecao,
              builder: (context, r, _) {
                if (r == null) return const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: _arrastando,
                  builder: (context, arrastando, _) => Stack(
                    children: [
                      Positioned.fromRect(
                        rect: r,
                        child: const IgnorePointer(
                          child: CustomPaint(painter: _RetanguloTracejado()),
                        ),
                      ),
                      for (final canto in [
                        r.topLeft,
                        r.topRight,
                        r.bottomLeft,
                        r.bottomRight,
                      ])
                        Positioned(
                          left: canto.dx - MapStyles.selectionHandleSize / 2,
                          top: canto.dy - MapStyles.selectionHandleSize / 2,
                          child: const IgnorePointer(child: _AlcaCanto()),
                        ),
                      if (!arrastando) _bolinhas(r),
                    ],
                  ),
                );
              },
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: MapStyles.selectionHintBottom,
              child: IgnorePointer(child: Center(child: _DicaSelecao())),
            ),
          ],
        );
      },
    );
  }

  Widget _bolinhas(Rect r) {
    const tam = MapStyles.selectionBubbleSize;
    const largura = tam * 2 + MapStyles.selectionBubbleGap;
    const folga = MapStyles.selectionBubbleOffset;
    final left = (r.right - largura)
        .clamp(folga, math.max(folga, _tamanho.width - largura - folga))
        .toDouble();
    final top = (r.top - tam - folga < folga) ? r.bottom + folga : r.top - tam - folga;

    return Positioned(
      left: left,
      top: top,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bolinha(
            icon: Icons.close_rounded,
            cor: MapStyles.selectionDiscardColor,
            tooltip: 'Descartar',
            onTap: _descartar,
          ),
          const SizedBox(width: MapStyles.selectionBubbleGap),
          _Bolinha(
            icon: Icons.check_rounded,
            cor: MapStyles.selectionConfirmColor,
            tooltip: 'Confirmar área',
            onTap: _confirmar,
          ),
        ],
      ),
    );
  }
}

class _Bolinha extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String tooltip;
  final VoidCallback onTap;

  const _Bolinha({
    required this.icon,
    required this.cor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: MapStyles.selectionBubbleSize,
        height: MapStyles.selectionBubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
          boxShadow: [
            BoxShadow(
              color: cor.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: cor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              icon,
              size: MapStyles.selectionBubbleIconSize,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlcaCanto extends StatelessWidget {
  const _AlcaCanto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MapStyles.selectionHandleSize,
      height: MapStyles.selectionHandleSize,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        border: Border.all(
          color: AppColors.primary,
          width: MapStyles.selectionStrokeWidth,
        ),
      ),
    );
  }
}

class _DicaSelecao extends StatelessWidget {
  const _DicaSelecao();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: MapStyles.selectionHintPadding,
      decoration: MapStyles.selectionHintDecoration,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.highlight_alt, size: 16, color: AppColors.onPrimary),
          SizedBox(width: AppSpacing.sm),
          Text('Arraste para selecionar uma área',
              style: MapStyles.selectionHintText),
        ],
      ),
    );
  }
}

/// Retângulo com preenchimento leve e contorno tracejado.
class _RetanguloTracejado extends CustomPainter {
  const _RetanguloTracejado();

  @override
  void paint(Canvas canvas, Size size) {
    const cor = AppColors.primary;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = cor.withOpacity(MapStyles.selectionFillOpacity),
    );

    final traco = Paint()
      ..color = cor
      ..strokeWidth = MapStyles.selectionStrokeWidth
      ..style = PaintingStyle.stroke;

    void linha(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total == 0) return;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final fim = math.min(d + MapStyles.selectionDash, total);
        canvas.drawLine(a + dir * d, a + dir * fim, traco);
        d += MapStyles.selectionDash + MapStyles.selectionDashGap;
      }
    }

    final w = size.width, h = size.height;
    linha(Offset.zero, Offset(w, 0));
    linha(Offset(w, 0), Offset(w, h));
    linha(Offset(w, h), Offset(0, h));
    linha(Offset(0, h), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _RetanguloTracejado oldDelegate) => false;
}