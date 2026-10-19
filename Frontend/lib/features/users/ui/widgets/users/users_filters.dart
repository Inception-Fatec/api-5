import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_search_field.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/role_filter_dropdown.dart';

/// Linha com a busca (nome ou e-mail) e o filtro por perfil.
class UsersFilters extends StatelessWidget {
  final String searchQuery;
  final String selectedRole;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;

  const UsersFilters({
    super.key,
    required this.searchQuery,
    required this.selectedRole,
    required this.onSearchChanged,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    // O filtro estica até a altura do campo de busca.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppSearchField(
              hint: 'Buscar por nome ou e-mail...',
              initialText: searchQuery,
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RoleFilterDropdown(value: selectedRole, onChanged: onRoleChanged),
        ],
      ),
    );
  }
}
