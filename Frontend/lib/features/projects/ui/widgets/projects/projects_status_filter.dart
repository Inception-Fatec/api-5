import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
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
      _chip(
        label: 'Todos (${controller.contagemStatus(null)})',
        selected: selected == null,
        onTap: () => controller.setStatusFiltro(null),
      ),
      for (final status in projectStatusFilterOrder)
        if (controller.contagemStatus(status) > 0 || selected == status)
          _chip(
            label:
                '${ProjectStatusStyle.label(status)} (${controller.contagemStatus(status)})',
            color: ProjectStatusStyle.color(status),
            selected: selected == status,
            onTap: () => controller.setStatusFiltro(status),
          ),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ChoiceChip(
      avatar: color == null
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.chipBg,
      backgroundColor: AppColors.surface,
      side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}
