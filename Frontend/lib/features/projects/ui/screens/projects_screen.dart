import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/map/ui/screens/points_map_screen.dart';
import 'package:tecsys_app/features/projects/ui/widgets/new_project/new_project_dialog.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_mobile_view.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/projects_web_view.dart';
import 'package:tecsys_app/features/reports/ui/screens/reports_screen.dart';

/// "My Projects". [PageBody] garante Material ancestral em qualquer
/// contexto e [LayoutBuilder] escolhe entre mobile (lista) e web
/// (dashboard). Os dois layouts compartilham exatamente os mesmos
/// dados e a mesma lógica ([ProjectsListController]) — só o ARRANJO
/// muda entre eles.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProjectsListController()..carregarInicial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Novo Projeto": abre o popup de dados básicos e, se confirmado,
  /// segue para o mapa de pontos.
  Future<void> _goToNewProject() async {
    final resultado = await NewProjectDialog.mostrar(context);
    if (resultado == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsMapScreen(
          nomeProjeto: resultado.nome,
          distCode: resultado.distCode,
          distribuidoraLabel: resultado.distribuidoraLabel,
          municipios: resultado.municipios,
        ),
      ),
    );
  }

  void _openDetail(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= AppBreakpoints.web;
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => isWeb
                ? ProjectsWebView(
                    controller: _controller,
                    onNewProject: _goToNewProject,
                    onOpenProject: _openDetail,
                  )
                : ProjectsMobileView(
                    controller: _controller,
                    onNewProject: _goToNewProject,
                    onOpenProject: _openDetail,
                  ),
          );
        },
      ),
    );
  }
}
