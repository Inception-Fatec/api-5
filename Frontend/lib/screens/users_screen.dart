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


/// Users screen — gestão de usuários (US-34). Mesmo padrão das outras
/// telas do shell (ProjectsScreen/MapScreen/NewProjectScreen):
/// [PageBody] garante Material ancestral, [LayoutBuilder] escolhe entre
/// layout mobile (lista empilhada) e web (grade + header em linha), e a
/// navegação/BottomNav some daqui — quem monta isso é só o AppShell.
///
/// RN04 / CA07: rota restrita a ADM. Um USER que cair aqui (deep link,
/// state antigo etc.) vê um bloqueio inline com o mesmo aviso e é
/// redirecionado pro AppShell.
///
/// RN03: o backend não devolve id de volta no login (AuthResponseDto
/// só tem token/role/mustChangePassword), então "é você mesmo" é
/// decidido comparando `AuthService.instance.email` com o e-mail de
/// cada linha da lista — e-mail é único, funciona como um id faria.
///
/// Ponto que ainda depende de um arquivo que eu não tenho:
/// pressupõe que `AddUserDialog` devolve um objeto com `fullName`,
/// `email`, `password` e `role` (String 'ADM'/'USER') — o campo
/// `password` é novo em relação ao protótipo original, porque o
/// backend exige senha no cadastro (UserCreateDto). Se o dialog atual
/// não tiver esse campo, precisa adicionar.
///
/// Também falta registrar esta tela como aba no AppShell (com item de
/// nav visível só pra ADM) — não mexi em app_shell.dart/nav_items.dart
/// porque isso toca a fonte única de navegação; confirma comigo antes
/// se quiser que eu faça essa parte também.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _webBreakpoint = 900.0;
  static const _homeTabIndex = 0; // aba "Projects" no AppShell

  List<AppUser> _members = [];
  bool _isLoading = true;
  String? _loadError;
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _checkAccessThenLoad();
  }

  // RN04/CA07 — bloqueia USER antes mesmo de tentar carregar a lista
  // (o backend também bloqueia via @PreAuthorize, isso aqui é só UX).
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
      // CA02 — mensagem de sucesso mapeada no DoR.
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
      // Cobre o 409 de e-mail duplicado e outros erros de validação
      // que o backend devolver — a mensagem já vem pronta do ApiClient.
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
        // CA06 — auto-exclusão de ADM encerra a sessão ativa. Reusa o
        // mesmo helper de logout do menu de conta (account_actions.dart)
        // em vez de reimplementar a navegação de volta ao login.
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
      // CA05 — 403 ao tentar excluir outro ADM (não deveria disparar,
      // já que o botão fica oculto, mas cobre corrida/estado velho).
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
  // WEB LAYOUT
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Users',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              _CountChip(count: _members.length),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Contas e níveis de acesso da plataforma',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
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
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add User', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildContent(gridColumns: 2),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
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
                  Image.asset('assets/images/logo.png', height: 26),
                  const Spacer(),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TECSYS B2B',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Users',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, size: 18, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Text(
                    'Users',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  _CountChip(count: _members.length),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Contas e níveis de acesso da plataforma',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
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
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add User', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildContent(gridColumns: 1),
            ]),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // CONTEÚDO COMPARTILHADO (loading / erro / bloqueio / lista)
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
    if (_members.isEmpty) {
      return const _InlineMessage(
        icon: Icons.people_outline,
        title: 'Nenhum usuário cadastrado',
        message: 'Use "Add User" para criar o primeiro acesso.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TEAM MEMBERS (${_members.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4),
            ),
            const Text('Role Filter: All', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (gridColumns == 1)
          Column(
            children: [
              for (final member in _members) ...[
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
                children: _members
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

/// Mesmo visual do protótipo original, agora orientado por [AppUser] e
/// por RN03: o botão de excluir some para ADMs que não sejam o próprio
/// usuário logado.
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
    // RN03: ADM nunca pode excluir outro ADM — só USER ou a si mesmo.
    final canDelete = !isAdmin || isSelf;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
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
                backgroundColor: const Color(0xFFF0F1F4),
                child: Text(
                  member.initials,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          const Text('(você)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                    Text(member.email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? AppColors.background : const Color(0xFFF0F1F4),
                  borderRadius: BorderRadius.circular(100),
                  border: isAdmin ? Border.all(color: AppColors.primary, width: 1.2) : null,
                ),
                child: Text(
                  member.role.label,
                  style: TextStyle(
                    fontSize: 11,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Excluir fica oculto (não só desabilitado) pra ADM ler outro
              // ADM — bate com o esboço de UX do DoR ("oculto/desabilitado").
              if (canDelete)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}