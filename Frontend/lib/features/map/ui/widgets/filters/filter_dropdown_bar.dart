import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_bar_header.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_buttons_row.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Barra de filtros sobre o mapa: distribuidora, cidades, total de
/// pontos e os botões de filtro. Lê e altera o [controller]; só a troca
/// de cidade sobe para a tela (o mapa precisa saltar até lá).
class FilterDropdownBar extends StatelessWidget {
  final PointsMapController controller;
  final ValueChanged<Municipio> onToggleCity;

  const FilterDropdownBar({
    super.key,
    required this.controller,
    required this.onToggleCity,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: FiltersStyles.barMargin,
            padding: FiltersStyles.barPadding,
            decoration: FiltersStyles.barDecoration,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final total = controller.totalPontos;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterBarHeader(
                      controller: controller,
                      onToggleCity: onToggleCity,
                    ),
                    if (total != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('$total ponto(s)', style: AppTextStyles.caption),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    FilterButtonsRow(controller: controller),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
