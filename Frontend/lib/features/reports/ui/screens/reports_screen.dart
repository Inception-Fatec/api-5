import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';
import 'package:tecsys_app/features/projects/ui/abrir_projeto_no_mapa.dart';
import 'package:tecsys_app/features/projects/ui/widgets/project_versions_sheet.dart';
import 'package:tecsys_app/features/reports/export/report_map_capture.dart';
import 'package:tecsys_app/features/reports/export/report_pdf.dart';
import 'package:tecsys_app/features/reports/state/report_controller.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_header.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_view.dart';

/// Tela de relatório do projeto — pra onde o card clicável da
/// ProjectsScreen leva. Mostra o estudo que o motor de decisão já
/// salvou: resumo, mancha de cobertura, gateways propostos e parâmetros
/// (ver [ReportView]).
///
/// "Abrir no mapa" (e "Recalcular projeto", quando o cálculo falhou) abre
/// o mapa com a área e os filtros da última versão (#TG-86). Depois de
/// recalcular, abre direto o relatório da versão nova. "Versões" lista o
/// histórico do projeto (data e filtros de cada versão, CA4 da US #19).
///
/// O nome da classe continua [ProjectDetailScreen] para não mexer na
/// navegação da ProjectsScreen.
class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ReportController _controller;
  bool _exportingPdf = false;
  bool _abrindoMapa = false;

  @override
  void initState() {
    super.initState();
    _controller = ReportController(project: widget.project)
      ..carregar()
      // Projeto ainda calculando: a tela se atualiza sozinha ao terminar.
      ..iniciarAtualizacaoAutomatica();
    // Abrir o relatório conta como atividade: sobe nos Recentes (#TG-88).
    ProjectsStore.instance.registrarAtividade(widget.project.id);
    _carregarNomes();
  }

  /// Nomes de municípios (IBGE) e distribuidoras usados nos parâmetros
  /// do relatório; sem eles, aparecem os códigos.
  Future<void> _carregarNomes() async {
    await IbgeService().precarregar();
    try {
      await DistribuidorasService().listar();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Cidades do cálculo: as dos filtros do relatório ou, enquanto ele não
  /// carrega, as que vieram com o projeto (#TG-148).
  String _cidades() {
    final codigos = _controller.report?.filters?.munCodes ?? widget.project.munCodes;
    return IbgeService.rotulosMunicipios(codigos);
  }

  Future<void> _exportPdf() async {
    final report = _controller.report;
    if (report == null || _exportingPdf) return;
    final project = widget.project;
    setState(() => _exportingPdf = true);
    try {
      // Foto do mapa (mancha + gateways); null = PDF sai sem a imagem.
      final mapImage = await captureReportMap(context, report);
      final bytes = await buildReportPdf(
        projectName: project.name,
        distribuidora: nomeDistribuidora(project.distCode),
        date: project.dataFormatada,
        cidades: _cidades(),
        report: report,
        mapImage: mapImage,
      );
      await Printing.sharePdf(
          bytes: bytes, filename: 'relatorio-cobertura-${project.id}.pdf');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o PDF agora.')));
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  /// Abre o projeto no mapa com a última versão do histórico (#TG-86).
  Future<void> _abrirNoMapa() async {
    if (_abrindoMapa) return;
    setState(() => _abrindoMapa = true);
    try {
      final recalculado = await abrirProjetoNoMapa(context, widget.project);
      // Recalculou: abre direto o relatório da versão nova, que mostra
      // "Cálculo em andamento" e se atualiza sozinho quando terminar.
      if (recalculado != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute<Project>(
            builder: (_) => ProjectDetailScreen(project: recalculado)));
      }
    } finally {
      if (mounted) setState(() => _abrindoMapa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => ReportHeader(
              project: widget.project,
              status: _controller.statusProjeto,
              cidades: _cidades(),
              onExportPdf: _controller.status == ReportStatus.ready
                  ? _exportPdf
                  : null,
              exportingPdf: _exportingPdf,
              // Enquanto calcula não dá para recalcular de novo.
              onOpenMap: _controller.status == ReportStatus.calculating
                  ? null
                  : _abrirNoMapa,
              abrindoMapa: _abrindoMapa,
              onVersions: () =>
                  ProjectVersionsSheet.mostrar(context, widget.project),
            ),
          ),
          Expanded(
            child: ReportView(
              controller: _controller,
              // Cálculo que falhou: abre no mapa com os mesmos filtros para
              // recalcular (#TG-86).
              onRedo: _abrirNoMapa,
            ),
          ),
        ],
      ),
    );
  }
}
