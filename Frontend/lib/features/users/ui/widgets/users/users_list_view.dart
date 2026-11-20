import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/card_grid.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/ui/styles/users_styles.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/user_card.dart';

/// Lista (mobile) ou grid (web) de usuários, com o estado vazio.
/// [hasAnyUser] diferencia "ninguém cadastrado" de "nada na busca".
class UsersListView extends StatelessWidget {
  final List<AppUser> members;
  final bool hasAnyUser;
  final bool grid;
  final ValueChanged<AppUser> onDelete;

  /// Redefinir a senha de quem esqueceu. Só para o perfil Usuário: a senha
  /// de outro administrador não pode ser redefinida (regra do backend) e a
  /// própria se troca pelo menu da conta.
  final ValueChanged<AppUser>? onResetPassword;

  const UsersListView({
    super.key,
    required this.members,
    required this.hasAnyUser,
    required this.grid,
    required this.onDelete,
    this.onResetPassword,
  });

  Widget _card(AppUser member) => UserCard(
        key: ValueKey(member.id),
        member: member,
        onDelete: () => onDelete(member),
        onResetPassword:
            onResetPassword == null || member.role != UserRoleType.user
                ? null
                : () => onResetPassword!(member),
      );

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Padding(
        padding: UsersStyles.messagePadding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline,
                  size: UsersStyles.emptyStateIconSize,
                  color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text(
                hasAnyUser
                    ? 'Nenhum usuário encontrado para essa busca.'
                    : 'Nenhum usuário cadastrado.',
                textAlign: TextAlign.center,
                style: UsersStyles.emptyStateText,
              ),
            ],
          ),
        ),
      );
    }

    if (grid) {
      return CardGrid(
        spacing: UsersStyles.gridSpacing,
        children: members.map(_card).toList(),
      );
    }

    return Column(
      children: [
        for (final m in members) ...[
          _card(m),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
