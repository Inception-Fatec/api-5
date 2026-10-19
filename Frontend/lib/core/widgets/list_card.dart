import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/hover_card.dart';

/// Card de listagem padrão (projetos e usuários). Monta sempre a mesma
/// estrutura: avatar/identificação e selo no topo (com a lixeira
/// vermelha), título, subtítulo, divisor e linhas de informação. Assim
/// os cards das duas telas têm o mesmo tamanho, fontes e hover.
class ListCard extends StatelessWidget {
  /// Lado esquerdo do topo (avatar, e o que mais acompanhar).
  final Widget leading;

  /// Selo ao lado da lixeira (status, perfil).
  final Widget badge;

  /// Null desabilita a lixeira (ex: enquanto exclui).
  final VoidCallback? onDelete;

  final String title;
  final String subtitle;

  /// Normalmente [CardInfoRow]s; o espaçamento entre elas é automático.
  final List<Widget> infoRows;

  /// Quando informada, desenha uma faixa dessa cor no topo do card.
  final Color? accentColor;

  /// Null = card não clicável.
  final VoidCallback? onTap;

  /// Esmaece o card (ex: enquanto exclui).
  final bool dimmed;

  const ListCard({
    super.key,
    required this.leading,
    required this.badge,
    required this.onDelete,
    required this.title,
    required this.subtitle,
    required this.infoRows,
    this.accentColor,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      clickable: onTap != null,
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.xl,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.xl,
            child: ClipRRect(
              borderRadius: AppRadius.xl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (accentColor != null)
                    Container(
                        height: AppCardStyles.accentBarHeight,
                        color: accentColor),
                  Padding(
                    padding: AppCardStyles.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppCardStyles.headerGap),
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle),
                        const SizedBox(height: AppCardStyles.subtitleGap),
                        Text(subtitle, style: AppTextStyles.caption),
                        const SizedBox(height: AppCardStyles.dividerGap),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: AppCardStyles.dividerGap),
                        for (var i = 0; i < infoRows.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: AppCardStyles.infoGap),
                          infoRows[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: leading),
        const SizedBox(width: AppSpacing.sm),
        Row(
          children: [
            badge,
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onDelete,
              borderRadius: AppRadius.xxl,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.delete_outline,
                    size: AppCardStyles.deleteIconSize, color: AppColors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
