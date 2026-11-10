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
    this.cidades = '',
    this.onOpenMap,
    this.abrindoMapa = false,
    this.status,
    this.onVersions,
  });

  /// "Versões": histórico do projeto (#TG-85); nulo esconde.
  final VoidCallback? onVersions;

  /// Status atual (do servidor); null = o que veio com o projeto.
  final String? status;

  final Project project;

  /// Cidades do cálculo, ex.: "Aracruz - ES, Vitória - ES" (#TG-148).
  final String cidades;

  /// Botão "Exportar PDF"; nulo esconde (relatório ainda não pronto).
  final VoidCallback? onExportPdf;
  final bool exportingPdf;

  /// "Abrir no mapa" para ajustar os filtros e recalcular (#TG-86); nulo
  /// esconde (projeto ainda calculando).
  final VoidCallback? onOpenMap;
  final bool abrindoMapa;

  Widget _iconeMapa() => abrindoMapa
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.edit_location_alt_outlined, size: 18);

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.of(context).size.width >= AppBreakpoints.web;
    final statusAtual = status ?? project.status;
    final statusColor = ProjectStatusStyle.color(statusAtual);
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
                        if (cidades.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            cidades,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ReportStyles.rowLabel,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: AppRadius.pill),
                          child: Text(
                            ProjectStatusStyle.label(statusAtual),
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
                // Ações ao lado do PDF: com texto no web, só o ícone (com dica)
                // em tela estreita, para não espremer o nome do projeto.
                if (onOpenMap != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.xs, left: AppSpacing.xs),
                    child: largo
                        ? ElevatedButton.icon(
                            onPressed: abrindoMapa ? null : onOpenMap,
                            style: AppButtonStyles.primary(flat: true),
                            icon: _iconeMapa(),
                            label: const Text('Editar no mapa e recalcular'),
                          )
                        : IconButton.filled(
                            tooltip: 'Editar no mapa e recalcular',
                            onPressed: abrindoMapa ? null : onOpenMap,
                            style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary),
                            icon: _iconeMapa(),
                          ),
                  ),
                if (onVersions != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.xs, left: AppSpacing.xs),
                    child: largo
                        ? OutlinedButton.icon(
                            onPressed: onVersions,
                            style: AppButtonStyles.outlinedPrimary(
                                radius: AppRadius.md),
                            icon: const Icon(Icons.history, size: 18),
                            label: const Text('Versões'),
                          )
                        : IconButton.outlined(
                            tooltip: 'Versões',
                            onPressed: onVersions,
                            style: IconButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary)),
                            icon: const Icon(Icons.history),
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
