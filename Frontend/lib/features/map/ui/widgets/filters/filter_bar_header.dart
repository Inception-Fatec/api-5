import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/city_filter_panel.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/dropdown_filter_button.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Primeira linha da barra: distribuidora do projeto e seletor de cidades.
class FilterBarHeader extends StatelessWidget {
  final PointsMapController controller;
  final ValueChanged<Municipio> onToggleCity;

  const FilterBarHeader({
    super.key,
    required this.controller,
    required this.onToggleCity,
  });

  @override
  Widget build(BuildContext context) {
    final selecionadas = controller.municipiosSelecionados;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Chip(
            avatar: const Icon(
              Icons.business,
              size: FiltersStyles.distributorIconSize,
              color: AppColors.textSecondary,
            ),
            label: Text(
              controller.distribuidoraLabel,
              style: FiltersStyles.distributorText,
            ),
            backgroundColor: AppColors.chipBg,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: FiltersStyles.gap),
          DropdownFilterButton(
            label:
                selecionadas.map((m) => m.rotulo.split(' - ').first).join(', '),
            icon: Icons.location_city,
            ativo: true,
            panelBuilder: (context, fechar) => CityFilterPanel(
              disponiveis: controller.cidadesDisponiveis,
              selecionadas: controller.municipiosSelecionados,
              onToggle: onToggleCity,
            ),
          ),
        ],
      ),
    );
  }
}
