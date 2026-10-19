import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/data/services/user_api_service.dart';
import 'package:tecsys_app/features/users/ui/styles/user_role_style.dart';
import 'package:tecsys_app/features/users/ui/widgets/add_user_dialog.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/role_filter_dropdown.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/users_view.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _searchQuery = '';
  String _selectedRole = RoleFilterDropdown.all;

  bool _isLoading = true;
  String? _error;
  List<AppUser> _members = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// CA01 - carrega a lista real de usuários do backend.
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await UserApiService.instance.listUsers();
      if (!mounted) return;
      setState(() {
        _members = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AppUser> get _filteredMembers {
    return _members.where((member) {
      final matchesSearch =
          member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              member.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == RoleFilterDropdown.all ||
          member.role.label == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  int get _adminCount =>
      _members.where((m) => m.role == UserRoleType.adm).length;
  int get _userCount =>
      _members.where((m) => m.role == UserRoleType.user).length;

  /// CA02 - cadastra o usuário no backend e recarrega a lista.
  Future<void> _openAddUser() async {
    final result = await showAddUserDialog(context);
    if (result == null || !mounted) return;
    final role = result.role == 'ADMIN' ? UserRoleType.adm : UserRoleType.user;
    try {
      await UserApiService.instance.createUser(
        name: result.fullName,
        email: result.email,
        password: result.password,
        role: role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${result.fullName} adicionado como ${UserRoleStyle.label(role)}'),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar usuário: $e')),
      );
    }
  }

  /// CA05/CA06/RN03 - exclui via backend; 403 (excluir outro ADM) chega
  /// como ApiException e é mostrado na snackbar.
  Future<void> _handleDelete(AppUser member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover usuário'),
        content: Text('Tem certeza que deseja remover ${member.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await UserApiService.instance.deleteUser(member.id);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m.id == member.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover usuário: $e')),
      );
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Erro ao carregar usuários: $_error',
                textAlign: TextAlign.center, style: AppTextStyles.bodyError),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
                onPressed: _loadUsers, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) return _buildError();

          return UsersView(
            isWeb: constraints.maxWidth >= AppBreakpoints.web,
            total: _members.length,
            adminCount: _adminCount,
            userCount: _userCount,
            filteredMembers: _filteredMembers,
            searchQuery: _searchQuery,
            selectedRole: _selectedRole,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            onRoleChanged: (val) =>
                setState(() => _selectedRole = val ?? RoleFilterDropdown.all),
            onAddUser: _openAddUser,
            onRefresh: _loadUsers,
            onDelete: _handleDelete,
          );
        },
      ),
    );
  }
}
