import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Botão "Salvar Projeto" da base do mapa: mostra o progresso enquanto
/// salva e, depois, a confirmação com o total de pontos.
class SaveProjectButton extends StatelessWidget {
  final bool salvando;
  final bool salvo;
  final int? totalFinal;
  final VoidCallback? onPressed;

  const SaveProjectButton({
    super.key,
    required this.salvando,
    required this.salvo,
    required this.totalFinal,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: MapStyles.saveButtonHeight,
      child: ElevatedButton(
        onPressed: salvando ? null : onPressed,
        style: AppButtonStyles.primary(radius: AppRadius.lg).copyWith(
          // Desabilitado (salvando) mantém a cor padrão de botão inativo.
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return salvo ? AppColors.success : AppColors.primary;
          }),
          elevation:
              const WidgetStatePropertyAll(MapStyles.saveButtonElevation),
        ),
        child: salvando
            ? const SizedBox(
                width: MapStyles.saveSpinnerSize,
                height: MapStyles.saveSpinnerSize,
                child: CircularProgressIndicator(
                  strokeWidth: MapStyles.saveSpinnerStroke,
                  color: AppColors.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    salvo ? Icons.check_circle_outline : Icons.save_outlined,
                    size: MapStyles.saveButtonIconSize,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    salvo
                        ? 'Salvo — ${totalFinal ?? 0} ponto(s)'
                        : 'Salvar Projeto',
                    style: AppTextStyles.buttonTextLarge,
                  ),
                ],
              ),
      ),
    );
  }
}
