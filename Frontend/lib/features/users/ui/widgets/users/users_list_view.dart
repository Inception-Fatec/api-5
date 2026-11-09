import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
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

  const UsersListView({
    super.key,
    required this.members,
    required this.hasAnyUser,
    required this.grid,
    required this.onDelete,
  });

  Widget _card(AppUser member) => UserCard(
        key: ValueKey(member.id),
        member: member,
        onDelete: () => onDelete(member),
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
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= AppBreakpoints.wideGrid ? 3 : 2;
          const spacing = UsersStyles.gridSpacing;
          final cardWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: members
                .map((m) => SizedBox(width: cardWidth, child: _card(m)))
                .toList(),
          );
        },
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
