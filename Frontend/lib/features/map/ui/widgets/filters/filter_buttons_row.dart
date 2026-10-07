import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/data/constants/map_filter_options.dart';
import 'package:tecsys_app/features/map/state/points_map_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/bairro_autocomplete_field.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/checkbox_filter_panel.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/chip_filter_panel.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/dropdown_filter_button.dart';

/// Linha rolável com os botões de filtro: bairro, nível de tensão,
/// conjunto, subestação, classe e CNAE.
class FilterButtonsRow extends StatelessWidget {
  final PointsMapController controller;

  const FilterButtonsRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final targetLayers = controller.targetLayers;

    final botoes = <Widget>[
      DropdownFilterButton(
        label: 'Bairro',
        icon: Icons.signpost_outlined,
        ativo: controller.bairroNames.isNotEmpty,
        panelBuilder: (context, fechar) => Padding(
          padding: FiltersStyles.panelPadding,
          child: BairroAutocompleteField(
            munCodes: controller.munCodes,
            values: controller.bairroNames,
            onChanged: controller.setBairros,
          ),
        ),
      ),
      DropdownFilterButton(
        label: targetLayers.isEmpty
            ? 'Nível de Tensão'
            : targetLayers.map(MapFilterOptions.targetLayerLabel).join(', '),
        icon: Icons.bolt_outlined,
        ativo: targetLayers.isNotEmpty,
        panelBuilder: (context, fechar) => CheckboxFilterPanel(
          title: 'Nível de Tensão',
          options: MapFilterOptions.targetLayers,
          selected: controller.targetLayers,
          labelOf: MapFilterOptions.targetLayerLabel,
          onChanged: controller.setTargetLayers,
        ),
      ),
      DropdownFilterButton(
        label: 'Conjunto',
        icon: Icons.hub_outlined,
        ativo: controller.conjCodes.isNotEmpty,
        panelBuilder: (context, fechar) => ChipFilterPanel(
          label: 'Conjunto Elétrico',
          hint: 'ex: 17113',
          values: controller.conjCodes,
          onChanged: controller.setConjCodes,
        ),
      ),
      DropdownFilterButton(
        label: 'Subestação',
        icon: Icons.electrical_services_outlined,
        ativo: controller.subCodes.isNotEmpty,
        panelBuilder: (context, fechar) => ChipFilterPanel(
          label: 'Subestação',
          hint: 'ex: SJC',
          values: controller.subCodes,
          onChanged: controller.setSubCodes,
        ),
      ),
      DropdownFilterButton(
        label: 'Classe',
        icon: Icons.category_outlined,
        ativo: controller.clasSub.isNotEmpty,
        panelBuilder: (context, fechar) => CheckboxFilterPanel(
          title: 'Classe / Subclasse',
          options: MapFilterOptions.clasSub,
          selected: controller.clasSub,
          optionStyle: FiltersStyles.optionText,
          scrollable: true,
          onChanged: controller.setClasSub,
        ),
      ),
      DropdownFilterButton(
        label: 'CNAE',
        icon: Icons.work_outline,
        ativo: controller.cnaeCodes.isNotEmpty,
        panelBuilder: (context, fechar) => ChipFilterPanel(
          label: 'Código CNAE',
          hint: 'ex: 3511-5/01',
          values: controller.cnaeCodes,
          onChanged: controller.setCnaeCodes,
        ),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < botoes.length; i++) ...[
            if (i > 0) const SizedBox(width: FiltersStyles.rowGap),
            botoes[i],
          ],
        ],
      ),
    );
  }
}
