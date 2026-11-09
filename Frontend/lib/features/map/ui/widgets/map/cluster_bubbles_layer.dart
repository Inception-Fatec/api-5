import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/point_cluster.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class ClusterBubblesLayer extends StatefulWidget {
  final Agrupamento agrupamento;
  final ValueChanged<PointCluster> onTap;

  final bool visivel;

  const ClusterBubblesLayer({
    super.key,
    required this.agrupamento,
    required this.onTap,
    this.visivel = true,
  });

  @override
  State<ClusterBubblesLayer> createState() => _ClusterBubblesLayerState();
}

class _Trajeto {
  final PointCluster bolha;
  final LatLng de;
  final LatLng para;
  const _Trajeto(this.bolha, this.de, this.para);
}

class _ClusterBubblesLayerState extends State<ClusterBubblesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: MapStyles.clusterRegroupDuration,
  );
  late final CurvedAnimation _curva =
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

  List<_Trajeto> _saindo = const [];
  List<_Trajeto> _entrando = const [];

  @override
  void didUpdateWidget(covariant ClusterBubblesLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.agrupamento, oldWidget.agrupamento)) return;

    final antes = oldWidget.agrupamento;
    final depois = widget.agrupamento;
    final animar =
        widget.visivel && oldWidget.visivel && antes.bolhas.isNotEmpty;
    if (!animar) {
      _anim.value = 1;
      _saindo = const [];
      _entrando = const [];
      return;
    }

    _saindo = [
      for (final b in antes.bolhas)
        _Trajeto(b, b.position, depois.bolhaEm(b.position)?.position ?? b.position),
    ];
    _entrando = [
      for (final b in depois.bolhas)
        _Trajeto(b, antes.bolhaEm(b.position)?.position ?? b.position, b.position),
    ];
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    _curva.dispose();
    _anim.dispose();
    super.dispose();
  }

  static String _numero(int n) {
    if (n < 1000) return '$n';
    if (n < 10000) {
      return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
    }
    if (n < 1000000) return '${n ~/ 1000} mil';
    return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} mi';
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  Marker _marcador(PointCluster b, LatLng onde, double alfa, {bool toque = false}) {
    final tamanho = MapStyles.clusterSize(b.count);
    final cor = MapStyles.clusterColor(b.count);
    final bolha = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cor.withOpacity(cor.opacity * alfa),
        border: Border.fromBorderSide(BorderSide(
          color: MapStyles.clusterBorderColor.withOpacity(alfa),
          width: MapStyles.clusterBorderWidth,
        )),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _numero(b.count),
              style: MapStyles.clusterText.copyWith(
                color: MapStyles.clusterText.color!.withOpacity(alfa),
                shadows: alfa < 1 ? const [] : MapStyles.clusterText.shadows,
              ),
            ),
          ),
        ),
      ),
    );
    return Marker(
      point: onde,
      width: tamanho,
      height: tamanho,
      child: toque
          ? GestureDetector(onTap: () => widget.onTap(b), child: bolha)
          : bolha,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      builder: (context, _) {
        final t = _curva.value;
        final parado = MarkerLayer(markers: [
          for (final b in widget.agrupamento.bolhas)
            _marcador(b, b.position, 1, toque: true),
        ]);
        if (t >= 1 || _entrando.isEmpty) return parado;

        final tela = MapCamera.of(context).visibleBounds;
        bool perto(_Trajeto j) =>
            tela.contains(j.de) || tela.contains(j.para);
        final saindo = _saindo.where(perto).toList();
        final entrando = _entrando.where(perto).toList();
        if (saindo.length + entrando.length > MapStyles.clusterMaxAnimated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _anim.value = 1;
          });
          return parado;
        }

        return MarkerLayer(markers: [
          for (final j in saindo) _marcador(j.bolha, _lerp(j.de, j.para, t), 1 - t),
          for (final j in entrando)
            _marcador(j.bolha, _lerp(j.de, j.para, t), t, toque: true),
        ]);
      },
    );
  }
}
