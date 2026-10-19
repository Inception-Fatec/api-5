import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_footer.dart';
import 'package:tecsys_app/core/widgets/page_title.dart';
import 'package:tecsys_app/core/widgets/primary_action_button.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/ui/styles/users_styles.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/users_filters.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/users_list_view.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/users_metrics.dart';

/// Conteúdo da tela de usuários (web e mobile): mesmos blocos e mesma
/// ordem da tela de Projetos; [isWeb] só muda o arranjo (botão ao lado
/// do título e cards em grade).
class UsersView extends StatelessWidget {
  final bool isWeb;
  final int total;
  final int adminCount;
  final int userCount;
  final List<AppUser> filteredMembers;
  final String searchQuery;
  final String selectedRole;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onAddUser;
  final Future<void> Function() onRefresh;
  final ValueChanged<AppUser> onDelete;

  const UsersView({
    super.key,
    required this.isWeb,
    required this.total,
    required this.adminCount,
    required this.userCount,
    required this.filteredMembers,
    required this.searchQuery,
    required this.selectedRole,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onAddUser,
    required this.onRefresh,
    required this.onDelete,
  });

  Widget _title() => PageTitle(
        title: 'Usuários',
        countLabel: '$total ${total == 1 ? "usuário" : "usuários"}',
        fontSize:
            isWeb ? UsersStyles.webTitleSize : UsersStyles.mobileTitleSize,
      );

  Widget _header() {
    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _title()),
          PrimaryActionButton(
            label: 'Novo Usuário',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onAddUser,
            full: false,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: 'Novo Usuário',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: onAddUser,
          full: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: isWeb
                ? UsersStyles.webPagePadding
                : UsersStyles.mobilePagePadding,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: AppSpacing.lg),
                  UsersMetrics(
                      total: total, admins: adminCount, users: userCount),
                  const SizedBox(height: AppSpacing.lg),
                  UsersFilters(
                    searchQuery: searchQuery,
                    selectedRole: selectedRole,
                    onSearchChanged: onSearchChanged,
                    onRoleChanged: onRoleChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  UsersListView(
                    members: filteredMembers,
                    hasAnyUser: total > 0,
                    grid: isWeb,
                    onDelete: onDelete,
                  ),
                  if (isWeb) const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [AppFooter()],
            ),
          ),
        ],
      ),
    );
  }
}
