import 'package:flutter/material.dart';

import 'package:tecsys_app/core/widgets/app_filter_chip.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/project_status_style.dart';

/// Status oferecidos no filtro, na ordem em que aparecem.
const projectStatusFilterOrder = [
  'SUCESSO',
  'PROCESSANDO',
  'ENVIADO',
  'CRIADO',
  'FALHA',
];

/// Chips de filtro por status, com a contagem de cada um. Status sem
/// projetos ficam escondidos (a menos que estejam selecionados).
class ProjectsStatusFilter extends StatelessWidget {
  final ProjectsListController controller;

  const ProjectsStatusFilter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final selected = controller.statusFiltro;
    final chips = <Widget>[
      AppFilterChip(
        label: 'Todos (${controller.contagemStatus(null)})',
        selected: selected == null,
        onTap: () => controller.setStatusFiltro(null),
      ),
      for (final status in projectStatusFilterOrder)
        if (controller.contagemStatus(status) > 0 || selected == status)
          AppFilterChip(
            label:
                '${ProjectStatusStyle.label(status)} (${controller.contagemStatus(status)})',
            color: ProjectStatusStyle.color(status),
            selected: selected == status,
            onTap: () => controller.setStatusFiltro(status),
          ),
    ];
    return AppFilterChipRow(chips: chips);
  }
}
