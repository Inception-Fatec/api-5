import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/new_project_dialog_styles.dart';

/// Escolha das cidades do projeto: carregando, vazio ou uma caixa de
/// seleção por cidade disponível.
class NewProjectCitiesField extends StatelessWidget {
  final NewProjectDialogController controller;

  const NewProjectCitiesField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.carregando) {
      return const Padding(
        padding: NewProjectDialogStyles.loadingPadding,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cidades = controller.cidadesDisponiveis;
    if (cidades == null || cidades.isEmpty) {
      return const Text(
        'Nenhuma cidade com dado disponível.',
        style: AppTextStyles.bodySmallError,
      );
    }

    return Column(
      children: cidades
          .map((m) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: controller.cidadesSelecionadas.contains(m),
                title: Text(m.rotulo),
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    controller.marcarCidade(m, marcada: v == true),
              ))
          .toList(),
    );
  }
}
