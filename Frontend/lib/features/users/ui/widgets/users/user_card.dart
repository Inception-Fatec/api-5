import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/card_avatar.dart';
import 'package:tecsys_app/core/widgets/card_info_row.dart';
import 'package:tecsys_app/core/widgets/list_card.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/ui/styles/user_role_style.dart';

/// Card de um usuário na lista: o [ListCard] padrão com a cor do perfil
/// em destaque (faixa no topo, avatar e ícones). Não conhece serviço
/// nem diálogo: excluir vem por [onDelete] e redefinir a senha por
/// [onResetPassword] (null = sem a ação, ex.: administradores).
class UserCard extends StatelessWidget {
  final AppUser member;
  final VoidCallback onDelete;
  final VoidCallback? onResetPassword;

  const UserCard({
    super.key,
    required this.member,
    required this.onDelete,
    this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final color = UserRoleStyle.color(member.role);

    return ListCard(
      accentColor: color,
      leading: CardAvatar(color: color, initials: member.initials),
      badge: StatusBadge(
        label: UserRoleStyle.badge(member.role),
        color: color,
        softColor: UserRoleStyle.softColor(member.role),
      ),
      onDelete: onDelete,
      actions: [
        if (onResetPassword != null)
          Tooltip(
            message: 'Redefinir senha',
            child: InkWell(
              key: Key('redefinir-senha-${member.id}'),
              onTap: onResetPassword,
              borderRadius: AppRadius.xxl,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.key_outlined,
                    size: AppCardStyles.deleteIconSize, color: color),
              ),
            ),
          ),
      ],
      title: member.name,
      subtitle: 'ID #${member.id}',
      infoRows: [
        CardInfoRow(icon: Icons.mail_outline, text: member.email, color: color),
        CardInfoRow(
          icon: UserRoleStyle.icon(member.role),
          text: UserRoleStyle.label(member.role),
          color: color,
        ),
      ],
    );
  }
}
