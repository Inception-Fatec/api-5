import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/constants/map_regions.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_dropdown_bar.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_back_button.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/points_map_view.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/save_project_button.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/zoom_hint_banner.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Mapa de pontos de um projeto novo: filtros por cima do mapa e o
/// botão que salva o projeto com os filtros escolhidos. Estado e regras
/// ficam no [PointsMapController]; aqui só a composição e a navegação.
class PointsMapScreen extends StatefulWidget {
  final String nomeProjeto;
  final String distCode;
  final String distribuidoraLabel;
  final List<Municipio> municipios;

  const PointsMapScreen({
    super.key,
    required this.nomeProjeto,
    required this.distCode,
    required this.distribuidoraLabel,
    required this.municipios,
  });

  @override
  State<PointsMapScreen> createState() => _PointsMapScreenState();
}

class _PointsMapScreenState extends State<PointsMapScreen> {
  final _mapKey = GlobalKey<PointsMapViewState>();
  late final PointsMapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PointsMapController(
      nomeProjeto: widget.nomeProjeto,
      distCode: widget.distCode,
      distribuidoraLabel: widget.distribuidoraLabel,
      municipios: widget.municipios,
      onFocusPoint: (ponto) =>
          _mapKey.currentState?.moverPara(ponto, MapRegions.zoomFiltro),
    )..carregarCidadesDisponiveis();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aoMarcarCidade(Municipio cidade) {
    final centro = _controller.alternarCidade(cidade);
    if (centro != null) {
      _mapKey.currentState?.moverPara(centro, MapRegions.zoomInicial);
    }
  }

  Future<void> _salvarProjeto() async {
    final salvou = await _controller.salvarProjeto();
    if (!mounted) return;

    if (salvou) {
      await Future.delayed(MapConfig.savedConfirmationDelay);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Não foi possível salvar agora. Tente de novo.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Stack(
          children: [
            PointsMapView(
              key: _mapKey,
              filtros: _controller.filtros,
              areas: _controller.areas,
              initialCenter: _controller.centroInicial,
              initialZoom: _controller.zoomInicial,
              onTotalChanged: _controller.setTotalPontos,
              onZoomMuitoBaixo: _controller.setZoomBaixoDemais,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapBackButton(onPressed: () => Navigator.of(context).pop()),
                  Expanded(
                    child: FilterDropdownBar(
                      controller: _controller,
                      onToggleCity: _aoMarcarCidade,
                    ),
                  ),
                ],
              ),
            ),
            if (_controller.zoomBaixoDemais)
              const Positioned(
                bottom: MapStyles.zoomHintBottom,
                left: MapStyles.zoomHintSideMargin,
                right: MapStyles.zoomHintSideMargin,
                child: ZoomHintBanner(),
              ),
            Positioned(
              left: MapStyles.saveBarInset,
              right: MapStyles.saveBarInset,
              bottom: MapStyles.saveBarInset,
              child: SafeArea(
                top: false,
                child: SaveProjectButton(
                  salvando: _controller.salvando,
                  salvo: _controller.projetoSalvo,
                  totalFinal: _controller.totalFinal,
                  onPressed: _controller.podeSalvar ? _salvarProjeto : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}