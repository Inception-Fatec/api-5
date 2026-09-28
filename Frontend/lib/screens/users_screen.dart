import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../navigation/account_actions.dart' show handleLogout;
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_api_service.dart';
import '../services/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/add_user_dialog.dart';
import '../widgets/common/app_footer.dart';
import '../widgets/common/page_body.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _webBreakpoint = 900.0;
  static const _homeTabIndex = 0;

  List<AppUser> _members = [];
  String _searchQuery = '';
  String _selectedRole = 'All';

  bool _isLoading = true;
  String? _loadError;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _checkAccessThenLoad();
  }

  /// RN04 / CA07 — Bloqueia usuários comuns (USER) antes de carregar os dados.
  void _checkAccessThenLoad() {
    final role = AuthService.instance.role;
    if (role != 'ADM') {
      setState(() {
        _accessDenied = true;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acesso negado: Requer privilégios de Administrador.'),
          ),
        );
        final shell = AppShell.of(context);
        if (shell != null) {
          shell.goToTab(_homeTabIndex);
        } else {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _loadUsers();
  }

  /// CA01 — Carrega a lista real de usuários do backend.
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final users = await UserApiService.instance.listUsers();
      if (!mounted) return;
      setState(() {
        _members = users;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Não foi possível conectar ao servidor.';
        _isLoading = false;
      });
    }
  }

  List<AppUser> get _filteredMembers {
    return _members.where((member) {
      final matchesSearch = member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          member.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'All' || member.role.label == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  int get _adminCount => _members.where((m) => m.role == UserRoleType.adm).length;
  int get _userCount => _members.where((m) => m.role == UserRoleType.user).length;

  /// CA02 — Cadastra o usuário no backend e recarrega a lista.
  Future<void> _openAddUser() async {
    final result = await showAddUserDialog(context);
    if (result == null || !mounted) return;

    try {
      await UserApiService.instance.createUser(
        name: result.fullName,
        email: result.email,
        password: result.password,
        role: result.role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usuário cadastrado com sucesso. A senha inicial exigirá alteração no primeiro acesso.',
          ),
        ),
      );
      await _loadUsers();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor.')),
      );
    }
  }

  bool _isSelf(AppUser member) {
    final myEmail = AuthService.instance.email;
    if (myEmail == null) return false;
    return member.email.toLowerCase() == myEmail.toLowerCase();
  }

  /// CA05/CA06/RN03 — Confirmação e remoção de usuário.
  Future<void> _confirmDelete(AppUser member) async {
    final isSelf = _isSelf(member);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? 'Excluir sua própria conta?' : 'Excluir usuário?'),
        content: Text(
          isSelf
              ? 'Isso vai excluir sua conta e encerrar sua sessão agora.'
              : 'Isso vai excluir a conta de ${member.name} (${member.email}).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteUser(member, isSelf: isSelf);
  }

  Future<void> _deleteUser(AppUser member, {required bool isSelf}) async {
    try {
      await UserApiService.instance.deleteUser(member.id);
      if (!mounted) return;

      if (isSelf) {
        await AuthService.instance.logout();
        if (!mounted) return;
        handleLogout(context);
        return;
      }

      setState(() => _members = _members.where((m) => m.id != member.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} removido.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= _webBreakpoint;
          return isWeb ? _buildWebBody(context) : _buildMobileBody(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DESKTOP / WEB LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildWebBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'T',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Usuários',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                _CountChip(count: _members.length),
                              ],
                            ),
                            const Text(
                              'Contas e níveis de acesso da plataforma',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _openAddUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add User', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatCards(),
                const SizedBox(height: 20),
                _buildSearchAndFilters(),
                const SizedBox(height: 24),
                _buildContent(gridColumns: 2),
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
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildMobileBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Usuários',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            _CountChip(count: _members.length),
                          ],
                        ),
                        const Text('Contas e níveis de acesso da plataforma', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildStatCards(),
              const SizedBox(height: 16),
              _buildSearchAndFilters(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _openAddUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add User', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 18),
              _buildContent(gridColumns: 1),
            ]),
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
    );
  }

  // ---------------------------------------------------------------------
  // COMPONENTES DE FILTRO E ESTATÍSTICAS
  // ---------------------------------------------------------------------

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(child: _StatPill(label: 'Total', value: '${_members.length}', color: const Color(0xFF0F172A))),
        const SizedBox(width: 8),
        Expanded(child: _StatPill(label: 'Admins', value: '$_adminCount', color: AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _StatPill(label: 'Users', value: '$_userCount', color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              icon: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
              items: ['All', 'ADMIN', 'USER'].map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedRole = val ?? 'All'),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // RENDERIZAÇÃO DO CONTEÚDO (ESTADOS)
  // ---------------------------------------------------------------------

  Widget _buildContent({required int gridColumns}) {
    if (_accessDenied) {
      return const _InlineMessage(
        icon: Icons.lock_outline,
        title: 'Acesso negado',
        message: 'Requer privilégios de Administrador.',
      );
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return _InlineMessage(
        icon: Icons.error_outline,
        title: 'Não foi possível carregar os usuários',
        message: _loadError!,
        onRetry: _loadUsers,
      );
    }
    
    final filtered = _filteredMembers;
    if (filtered.isEmpty) {
      return const _InlineMessage(
        icon: Icons.search_off_rounded,
        title: 'Nenhum usuário encontrado',
        message: 'Tente alterar os termos da busca ou os filtros.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEAM MEMBERS (${filtered.length})',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (gridColumns == 1)
          Column(
            children: [
              for (final member in filtered) ...[
                _MemberCard(
                  member: member,
                  isSelf: _isSelf(member),
                  onDelete: () => _confirmDelete(member),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          )
        else
          LayoutBuilder(
            builder: (context, gridConstraints) {
              const spacing = AppSpacing.md;
              final cardWidth = (gridConstraints.maxWidth - spacing * (gridColumns - 1)) / gridColumns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: filtered
                    .map((m) => SizedBox(
                          width: cardWidth,
                          child: _MemberCard(
                            member: m,
                            isSelf: _isSelf(m),
                            onDelete: () => _confirmDelete(m),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------------------

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        '$count ${count == 1 ? 'account' : 'accounts'}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _InlineMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E8EF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final AppUser member;
  final bool isSelf;
  final VoidCallback onDelete;

  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.role == UserRoleType.adm;
    final canDelete = !isAdmin || isSelf;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8EF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isAdmin ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF0F1F4),
                child: Text(
                  member.initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isAdmin ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          const Text('(você)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                    Text(member.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF0F1F4),
                  borderRadius: BorderRadius.circular(100),
                  border: isAdmin ? Border.all(color: AppColors.primary, width: 1) : null,
                ),
                child: Text(
                  member.role.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isAdmin ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: Color(0xFFEDEFF3)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
            ],
          ),
        ],
      ),
    );
  }
}