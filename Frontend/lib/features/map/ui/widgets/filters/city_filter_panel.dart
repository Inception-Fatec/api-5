import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Painel de cidades: marcar uma cidade nova também leva o mapa até lá.
/// A última cidade marcada não pode ser desmarcada.
class CityFilterPanel extends StatelessWidget {
  final List<Municipio> disponiveis;
  final List<Municipio> selecionadas;
  final ValueChanged<Municipio> onToggle;

  const CityFilterPanel({
    super.key,
    required this.disponiveis,
    required this.selecionadas,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: FiltersStyles.panelPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cidade(s)', style: FiltersStyles.panelTitle),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Marcar uma cidade nova também pula o mapa pra lá.',
            style: FiltersStyles.panelHint,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...disponiveis.map((m) {
            final marcada = selecionadas.contains(m);
            final ehAUltima = marcada && selecionadas.length == 1;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: marcada,
              title: Text(
                m.rotulo,
                style: TextStyle(
                    color: ehAUltima ? AppColors.textSecondary : null),
              ),
              activeColor: AppColors.primary,
              onChanged: ehAUltima ? null : (_) => onToggle(m),
            );
          }),
        ],
      ),
    );
  }
}
