import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';

/// Zoom pela roda do mouse mantendo o centro do mapa, usado no celular e
/// no emulador. O zoom padrão do flutter_map mira na posição do cursor,
/// que no emulador Android chega deslocada e faz o mapa "subir" a cada giro.
class CenterScrollZoom extends StatelessWidget {
  const CenterScrollZoom({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.onZoom,
  });

  /// Android/iOS: o mapa desliga a roda do flutter_map e usa este widget.
  static bool get ativo =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Maior passo de zoom por evento (a roda no Android chega com deltas grandes).
  static const _passoMaximo = 0.5;

  final MapController controller;
  final Widget child;
  final bool enabled;
  final VoidCallback? onZoom;

  void _aoRolar(PointerSignalEvent evento) {
    if (!enabled || evento is! PointerScrollEvent) return;
    if (evento.scrollDelta.dy == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(evento, (evento) {
      final dy = (evento as PointerScrollEvent).scrollDelta.dy;
      final camera = controller.camera;
      final passo = (-dy * MapConfig.scrollWheelVelocity)
          .clamp(-_passoMaximo, _passoMaximo);
      final zoom = (camera.zoom + passo)
          .clamp(MapConfig.minZoom, MapConfig.maxZoom)
          .toDouble();
      if (zoom == camera.zoom) return;
      controller.move(camera.center, zoom);
      onZoom?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ativo) return child;
    return Listener(onPointerSignal: _aoRolar, child: child);
  }
}
