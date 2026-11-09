import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/ui/styles/users_styles.dart';

/// Filtro por perfil ao lado da busca. O valor guardado continua sendo
/// 'All' ou o `label` do perfil ('ADMIN' / 'USER'); só o texto exibido
/// é em português.
class RoleFilterDropdown extends StatelessWidget {
  static const all = 'All';

  final String value;
  final ValueChanged<String?> onChanged;

  const RoleFilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static final _options = <String, String>{
    all: 'Todos',
    UserRoleType.adm.label: 'Admin',
    UserRoleType.user.label: 'Usuário',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: UsersStyles.filterPadding,
      decoration: const BoxDecoration(
          color: AppColors.inputFill, borderRadius: AppRadius.lg),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          borderRadius: AppRadius.md,
          icon: const Icon(Icons.filter_list_rounded,
              size: 18, color: AppColors.textSecondary),
          items: _options.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: UsersStyles.filterText),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
