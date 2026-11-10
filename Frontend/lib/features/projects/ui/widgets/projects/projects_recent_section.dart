import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/ui/styles/project_status_style.dart';

/// Seção "Recentes" da tela de projetos (#TG-88): os projetos de atividade
/// mais recente (criar, recalcular ou abrir o relatório), em cartões
/// pequenos: lado a lado no web, um embaixo do outro em tela estreita.
/// Sem projetos, não aparece.
class ProjectsRecentSection extends StatelessWidget {
  final List<Project> projetos;
  final ValueChanged<Project> onOpen;

  /// Hora "agora" para o texto "há X min" (fixável nos testes).
  final DateTime? agora;

  const ProjectsRecentSection({
    super.key,
    required this.projetos,
    required this.onOpen,
    this.agora,
  });

  /// "agora", "há 5 min", "há 3 h", "ontem" ou a data.
  static String quando(DateTime data, DateTime agora) {
    final d = agora.difference(data);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    if (d.inDays < 2) return 'ontem';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(data.day)}/${dois(data.month)}/${data.year}';
  }

  /// Largura mínima de um cartão: abaixo disso eles ficam um por linha.
  static const larguraMinCartao = 180.0;

  @override
  Widget build(BuildContext context) {
    if (projetos.isEmpty) return const SizedBox.shrink();
    final hoje = agora ?? DateTime.now();
    const espaco = AppSpacing.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 18, color: AppColors.primary),
            SizedBox(width: AppSpacing.xs),
            Text('Recentes', style: AppTextStyles.cardTitle),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Web: os 5 lado a lado. Tela estreita: um embaixo do outro, sem
        // rolagem lateral (CT4).
        LayoutBuilder(builder: (context, c) {
          final porLinha = ((c.maxWidth + espaco) / (larguraMinCartao + espaco))
              .floor()
              .clamp(1, 5);
          final largura = (c.maxWidth - espaco * (porLinha - 1)) / porLinha;
          return Wrap(
            spacing: espaco,
            runSpacing: espaco,
            children: [
              for (final p in projetos)
                SizedBox(
                  width: largura,
                  child: _CartaoRecente(
                    projeto: p,
                    quando: quando(p.ultimaAtividade, hoje),
                    onTap: () => onOpen(p),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _CartaoRecente extends StatelessWidget {
  final Project projeto;
  final String quando;
  final VoidCallback onTap;

  const _CartaoRecente({
    required this.projeto,
    required this.quando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = projeto.status;
    final concluido = status == 'SUCESSO';
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Concluído abre o relatório; os demais abrem o mapa (CA2).
                  Icon(
                    concluido ? Icons.description_outlined : Icons.map_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      projeto.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  StatusBadge(
                    label: ProjectStatusStyle.label(status),
                    color: ProjectStatusStyle.color(status),
                    softColor: ProjectStatusStyle.softColor(status),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(quando,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
