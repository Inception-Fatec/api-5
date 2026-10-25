import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/ui/styles/project_status_style.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';

/// Cabeçalho fixo do relatório: voltar, nome do projeto, status e
/// metadados e, quando o relatório está pronto, o botão de exportar PDF.
class ReportHeader extends StatelessWidget {
  const ReportHeader({
    super.key,
    required this.project,
    this.onExportPdf,
    this.exportingPdf = false,
  });

  final Project project;

  /// Botão "Exportar PDF"; nulo esconde (relatório ainda não pronto).
  final VoidCallback? onExportPdf;
  final bool exportingPdf;

  @override
  Widget build(BuildContext context) {
    final statusColor = ProjectStatusStyle.color(project.status);
    return Material(
      color: AppColors.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  constraints: const BoxConstraints(
                      minWidth: ReportStyles.minTouchSize,
                      minHeight: ReportStyles.minTouchSize),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RELATÓRIO DE COBERTURA',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        const SizedBox(height: 2),
                        Text(
                          project.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '#${project.id} • ${nomeDistribuidora(project.distCode)} • ${project.dataFormatada}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ReportStyles.rowLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: AppRadius.pill),
                          child: Text(
                            ProjectStatusStyle.label(project.status),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onExportPdf != null)
                  exportingPdf
                      ? const SizedBox(
                          width: ReportStyles.minTouchSize,
                          height: ReportStyles.minTouchSize,
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Exportar PDF',
                          constraints: const BoxConstraints(
                              minWidth: ReportStyles.minTouchSize,
                              minHeight: ReportStyles.minTouchSize),
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              color: AppColors.textPrimary),
                          onPressed: onExportPdf,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
