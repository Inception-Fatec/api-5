import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/new_project_dialog_styles.dart';

/// Escolha das cidades do projeto (#TG-147): só depois de escolher a
/// distribuidora; busca por nome e lista com altura máxima (rola quando há
/// muitas cidades). Nenhuma vem marcada.
class NewProjectCitiesField extends StatelessWidget {
  final NewProjectDialogController controller;

  /// Altura máxima da lista de cidades antes de rolar.
  static const double alturaMaximaLista = 240;

  const NewProjectCitiesField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.carregando) {
      return const Padding(
        padding: NewProjectDialogStyles.loadingPadding,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.distCode == null) {
      return const Text(
        'Escolha a distribuidora para ver as cidades.',
        style: AppTextStyles.bodyMuted,
      );
    }

    final cidades = controller.cidadesDisponiveis;
    if (cidades == null || cidades.isEmpty) {
      return const Text(
        'Nenhuma cidade com dado disponível.',
        style: AppTextStyles.bodySmallError,
      );
    }

    final filtradas = controller.cidadesFiltradas;
    final selecionadas = controller.cidadesSelecionadas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('busca-cidades'),
          onChanged: controller.buscar,
          decoration: AppDecorations.filledInput(
            hint: 'Buscar cidade pelo nome',
            hintStyle: AppTextStyles.bodyMuted,
            contentPadding: NewProjectDialogStyles.fieldPadding,
            borderRadius: AppRadius.sm,
          ).copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$selecionadas de ${cidades.length} selecionada(s)',
          style: AppTextStyles.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: alturaMaximaLista),
          child: filtradas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('Nenhuma cidade com esse nome.',
                      style: AppTextStyles.bodyMuted),
                )
              : Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtradas.length,
                    itemBuilder: (context, i) {
                      final m = filtradas[i];
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: controller.cidadesSelecionadas.contains(m),
                        title: Text(m.rotulo),
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            controller.marcarCidade(m, marcada: v == true),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
