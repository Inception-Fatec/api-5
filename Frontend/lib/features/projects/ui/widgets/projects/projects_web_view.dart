import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_footer.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/projects_styles.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/new_project_button.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_list_view.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_metrics.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_search_field.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_title.dart';

/// Layout web (dashboard) da tela de projetos — mesmos dados e
/// mesma lógica do mobile, só o arranjo muda.
class ProjectsWebView extends StatelessWidget {
  final ProjectsListController controller;
  final VoidCallback onNewProject;
  final ValueChanged<Project> onOpenProject;

  const ProjectsWebView({
    super.key,
    required this.controller,
    required this.onNewProject,
    required this.onOpenProject,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: ProjectsStyles.webPagePadding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ProjectsTitle(
                        fontSize: ProjectsStyles.webTitleSize,
                        total: controller.totalProjetos,
                      ),
                    ),
                    NewProjectButton(onPressed: onNewProject, full: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ProjectsMetrics(
                    total: controller.totalProjetos,
                    calculados: controller.totalCalculados),
                const SizedBox(height: AppSpacing.lg),
                ProjectsSearchField(
                    initialText: controller.busca,
                    onChanged: controller.setBusca),
                const SizedBox(height: AppSpacing.lg),
                ProjectsListView(
                  controller: controller,
                  grid: true,
                  onNewProject: onNewProject,
                  onOpenProject: onOpenProject,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [AppFooter()]),
        ),
      ],
    );
  }
}
