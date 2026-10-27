import 'package:flutter/material.dart';

import 'package:tecsys_app/app/navigation/account_actions.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/state/report_controller.dart';

class ReportStatusView extends StatelessWidget {
  const ReportStatusView({super.key, required this.controller, this.onRedo});

  final ReportController controller;

  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ReportStatus.loading:
        return const _Message(
          loading: true,
          title: 'Carregando relatório...',
          message: 'Estudos grandes podem levar alguns segundos.',
        );
      case ReportStatus.empty:
        return const _Message(
          icon: Icons.map_outlined,
          title: 'Nenhum ponto no estudo',
          message:
              'O cálculo não encontrou pontos para os filtros escolhidos. '
              'Revise os filtros do projeto e calcule novamente.',
        );
      case ReportStatus.calculating:
        return const _Message(
          icon: Icons.hourglass_top_outlined,
          title: 'Cálculo em andamento',
          message: 'Seu relatório está sendo gerado. Ele abre sozinho assim '
              'que o cálculo terminar. você pode sair desta tela e voltar '
              'depois.',
          spinnerBelow: true,
        );
      case ReportStatus.calculationFailed:
        return _Message(
          icon: Icons.error_outline,
          title: 'O cálculo deste projeto falhou',
          message: onRedo == null
              ? 'Não há relatório para exibir.'
              : 'Não há relatório para exibir. Você pode refazer o projeto: '
                  'o formulário abre com o nome preenchido para escolher os '
                  'filtros de novo.',
          actionLabel: onRedo == null ? null : 'Refazer projeto',
          onAction: onRedo,
        );
      case ReportStatus.unauthorized:
        return _Message(
          icon: Icons.lock_outline,
          title: 'Sessão expirada ou sem permissão',
          message: 'Entre novamente para ver o relatório.',
          actionLabel: 'Entrar novamente',
          onAction: () => handleLogout(context),
        );
      case ReportStatus.error:
        return _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar o relatório',
          message: controller.errorMessage ?? 'Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: controller.tentarNovamente,
        );
      case ReportStatus.ready:
        return const SizedBox.shrink();
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
    this.spinnerBelow = false,
    this.actionLabel,
    this.onAction,
    this.showDisabledAction = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final bool loading;

  final bool spinnerBelow;
  final String? actionLabel;
  final VoidCallback? onAction;

  final bool showDisabledAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator()
            else if (icon != null)
              Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center, style: AppTextStyles.sectionLabel),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                textAlign: TextAlign.center, style: AppTextStyles.bodySmallMuted),
            if (spinnerBelow) ...[
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
            if (actionLabel != null && (onAction != null || showDisabledAction)) ...[
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: onAction,
                style: AppButtonStyles.primary(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
