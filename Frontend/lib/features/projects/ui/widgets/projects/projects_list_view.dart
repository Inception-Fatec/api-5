import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/projects_styles.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/project_card.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_empty_state.dart';

/// Lista (mobile) ou grid (web) de projetos, com os estados de
/// loading, erro e vazio.
class ProjectsListView extends StatelessWidget {
  final ProjectsListController controller;
  final bool grid;
  final VoidCallback onNewProject;
  final ValueChanged<Project> onOpenProject;

  const ProjectsListView({
    super.key,
    required this.controller,
    required this.grid,
    required this.onNewProject,
    required this.onOpenProject,
  });

  Widget _card(Project p) {
    return ProjectCard(
      key: ValueKey(p.id),
      data: p,
      creatorName: controller.nomeCriador(p.createdById),
      onOpen: () => onOpenProject(p),
      onDelete: () => controller.excluir(p.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller.loading && controller.projects.isEmpty) {
      return const Padding(
        padding: ProjectsStyles.loadingPadding,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.erro != null && controller.projects.isEmpty) {
      return Padding(
        padding: ProjectsStyles.messagePadding,
        child: Column(
          children: [
            Text(controller.erro!, style: AppTextStyles.bodyError),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: controller.recarregar,
                child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    final projetos = controller.projetosFiltrados;
    if (projetos.isEmpty) {
      if (controller.projects.isEmpty) {
        return ProjectsEmptyState(onNewProject: onNewProject);
      }
      return const Padding(
        padding: ProjectsStyles.messagePadding,
        child: Center(
          child: Text('Nenhum projeto encontrado para essa busca.',
              style: AppTextStyles.bodyMuted),
        ),
      );
    }
    if (grid) {
      return LayoutBuilder(
        builder: (context, gridConstraints) {
          final columns =
              gridConstraints.maxWidth >= AppBreakpoints.wideGrid ? 3 : 2;
          const spacing = ProjectsStyles.gridSpacing;
          final cardWidth =
              (gridConstraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: projetos
                .map((p) => SizedBox(width: cardWidth, child: _card(p)))
                .toList(),
          );
        },
      );
    }
    return Column(
      children: [
        for (final p in projetos) ...[
          _card(p),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
