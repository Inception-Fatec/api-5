import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/ui/styles/projects_styles.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/new_project_button.dart';

/// Estado vazio da lista (nenhum projeto criado ainda), com o atalho
/// para criar o primeiro.
class ProjectsEmptyState extends StatelessWidget {
  final VoidCallback onNewProject;

  const ProjectsEmptyState({super.key, required this.onNewProject});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ProjectsStyles.emptyStatePadding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: ProjectsStyles.emptyStateIconSize,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Nenhum projeto em andamento',
                style: ProjectsStyles.emptyStateText),
            const SizedBox(height: AppSpacing.md),
            NewProjectButton(onPressed: onNewProject, full: false),
          ],
        ),
      ),
    );
  }
}
