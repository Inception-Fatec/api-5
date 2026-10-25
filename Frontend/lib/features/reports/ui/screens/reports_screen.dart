import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/reports/export/report_map_capture.dart';
import 'package:tecsys_app/features/reports/export/report_pdf.dart';
import 'package:tecsys_app/features/reports/state/report_controller.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_header.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_view.dart';

/// Tela de relatório do projeto — pra onde o card clicável da
/// ProjectsScreen leva. Mostra o estudo que o motor de decisão já
/// salvou: resumo, mancha de cobertura, gateways propostos e parâmetros
/// (ver [ReportView]).
///
/// Fecha devolvendo o [Project] quando o usuário pede para refazer um
/// projeto que falhou (`Navigator.pop<Project>`).
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

  @override
  void initState() {
    super.initState();
    _controller = ReportController(project: widget.project)
      ..carregar()
      // Projeto ainda calculando: a tela se atualiza sozinha ao terminar.
      ..iniciarAtualizacaoAutomatica();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              onExportPdf: _controller.status == ReportStatus.ready
                  ? _exportPdf
                  : null,
              exportingPdf: _exportingPdf,
            ),
          ),
          Expanded(
            child: ReportView(
              controller: _controller,
              // Volta para a lista devolvendo o projeto: ela abre o
              // formulário de novo projeto já com o nome preenchido.
              onRedo: () => Navigator.of(context).pop<Project>(widget.project),
            ),
          ),
        ],
      ),
    );
  }
}
