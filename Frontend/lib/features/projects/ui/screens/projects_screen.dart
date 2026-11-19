import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/state/projects_list_controller.dart';
import 'package:tecsys_app/features/map/ui/screens/points_map_screen.dart';
import 'package:tecsys_app/features/projects/ui/abrir_projeto_no_mapa.dart';
import 'package:tecsys_app/features/projects/ui/screens/project_comparison_screen.dart';
import 'package:tecsys_app/features/projects/ui/styles/project_status_style.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/compare_projects_bar.dart';
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
    _carregarNomesDistribuidoras();
  }

  /// Nomes das distribuidoras para os cards; sem eles, o card mostra o
  /// código.
  Future<void> _carregarNomesDistribuidoras() async {
    try {
      await DistribuidorasService().listar();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Novo Projeto": abre o popup de dados básicos e, se confirmado,
  /// segue para o mapa de pontos.
  Future<void> _goToNewProject({String? nomeInicial}) async {
    final resultado =
        await NewProjectDialog.mostrar(context, nomeInicial: nomeInicial);
    if (resultado == null || !mounted) return;

    final criado = await Navigator.of(context).push<Project>(
      MaterialPageRoute<Project>(
        builder: (_) => PointsMapScreen(
          nomeProjeto: resultado.nome,
          distCode: resultado.distCode,
          distribuidoraLabel: resultado.distribuidoraLabel,
          municipios: resultado.municipios,
          gatewayProfileId: resultado.gatewayProfileId,
        ),
      ),
    );
    // Salvou: abre o relatório, que mostra "Cálculo em andamento" e troca
    // sozinho para o resultado quando o motor termina.
    if (criado != null && mounted) await _openDetail(criado);
  }

  Future<void> _openDetail(Project project) async {
    // O relatório devolve o projeto quando o usuário toca em "Refazer
    // projeto" (cálculo que falhou): abre o novo projeto com o mesmo nome.
    final refazer = await Navigator.of(context).push<Project>(
      MaterialPageRoute<Project>(
          builder: (_) => ProjectDetailScreen(project: project)),
    );
    if (refazer == null || !mounted) return;
    await _goToNewProject(nomeInicial: refazer.name);
  }

  /// Recentes (#TG-88, CA2): concluído ou ainda calculando abre o
  /// relatório, igual ao card da lista; os demais (falha) abrem o mapa com
  /// a última versão para ajustar e recalcular.
  Future<void> _abrirRecente(Project project) async {
    if (abreNoRelatorio(project.status)) return _openDetail(project);
    _controller.registrarAtividade(project.id);
    final recalculado = await abrirProjetoNoMapa(context, project);
    // Recalculou: abre direto o relatório da versão nova.
    if (recalculado != null && mounted) await _openDetail(recalculado);
  }

  /// Abre a comparação dos projetos marcados (o 1º é a referência).
  Future<void> _abrirComparacao() async {
    final projetos = _controller.selecionados;
    if (projetos.length < 2) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProjectComparisonScreen(projetos: projetos)));
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= AppBreakpoints.web;
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: isWeb
                      ? ProjectsWebView(
                          controller: _controller,
                          onNewProject: _goToNewProject,
                          onOpenProject: _openDetail,
                          onOpenRecent: _abrirRecente,
                        )
                      : ProjectsMobileView(
                          controller: _controller,
                          onNewProject: _goToNewProject,
                          onOpenProject: _openDetail,
                          onOpenRecent: _abrirRecente,
                        ),
                ),
                if (_controller.comparando)
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: CompareSelectionBar(
                          controller: _controller,
                          onComparar: _abrirComparacao,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
