import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class MapOverviewLoading extends StatelessWidget {
  const MapOverviewLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(
      child: ColoredBox(
        color: MapStyles.overviewScrim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: MapStyles.overviewSpinnerSize,
                height: MapStyles.overviewSpinnerSize,
                child: CircularProgressIndicator(
                  strokeWidth: MapStyles.overviewSpinnerStroke,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: MapStyles.overviewGap),
              Text('Carregando pontos do mapa…',
                  style: MapStyles.overviewText),
            ],
          ),
        ),
      ),
    );
  }
}
