import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';

/// Cartão branco com contorno, base de todas as seções do relatório.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.child,
    this.padding = ReportStyles.cardPadding,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Recorta o filho nos cantos arredondados (usado pelo mapa).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Seção do relatório: título (com ícone) e conteúdo dentro de um cartão.
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: ReportStyles.sectionTitle),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: ReportStyles.rowLabel),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// Linha "rótulo ........ valor" das fichas do relatório. O rótulo e o
/// valor ocupam só o que precisam (nada de quebrar "Candidatos avaliados"
/// em duas linhas); [showDivider] desenha o fio de tabela embaixo.
class ReportKeyValueRow extends StatelessWidget {
  const ReportKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.showDivider = true,
  });

  final String label;
  final String value;

  /// Observação menor embaixo do valor (ex.: "1,9% da rede").
  final String? caption;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.divider))
            : null,
      ),
      // spaceBetween: rótulo colado à esquerda e valor colado à direita.
      // (Flexible + Expanded com o mesmo flex repartia o espaço ao meio e o
      // valor ficava "no meio" da linha.)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text(label, style: ReportStyles.rowLabel)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    textAlign: TextAlign.end, style: ReportStyles.rowValue),
                if (caption != null)
                  Text(caption!,
                      textAlign: TextAlign.end, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
