import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';

/// Liga/desliga o modo de selecionar projetos para comparar.
class CompareProjectsButton extends StatelessWidget {
  const CompareProjectsButton({super.key, required this.controller});

  final ProjectsListController controller;

  @override
  Widget build(BuildContext context) {
    final ativo = controller.comparando;
    return OutlinedButton.icon(
      key: const Key('comparar-projetos'),
      onPressed: controller.alternarComparacao,
      icon: Icon(ativo ? Icons.close_rounded : Icons.compare_arrows_rounded,
          size: 18),
      label: Text(ativo ? 'Cancelar comparação' : 'Comparar projetos'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      ),
    );
  }
}

/// Barra fixa no rodapé enquanto seleciona: quantos foram marcados e o
/// botão que abre a comparação (a partir de 2).
class CompareSelectionBar extends StatelessWidget {
  const CompareSelectionBar({
    super.key,
    required this.controller,
    required this.onComparar,
  });

  final ProjectsListController controller;
  final VoidCallback onComparar;

  @override
  Widget build(BuildContext context) {
    final n = controller.selecionados.length;
    return Material(
      color: AppColors.textPrimary,
      elevation: 6,
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                n == 0
                    ? 'Marque 2 ou mais projetos concluídos'
                    : '$n selecionado${n == 1 ? '' : 's'}'
                        '${n < 2 ? ' · marque mais 1' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: controller.alternarComparacao,
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              key: const Key('abrir-comparacao'),
              onPressed: controller.podeAbrirComparacao ? onComparar : null,
              icon: const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text('Comparar${n >= 2 ? ' ($n)' : ''}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white54,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
