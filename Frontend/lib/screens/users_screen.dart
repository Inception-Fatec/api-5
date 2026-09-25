import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'add_user_dialog.dart';

class _TeamMember {
  final String name;
  final String email;
  final String role;
  final String addedDate;

  const _TeamMember({
    required this.name,
    required this.email,
    required this.role,
    required this.addedDate,
  });

  String get initials {
    final parts = name.trim().split(' ');
    final first = parts.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _searchQuery = '';
  String _selectedRole = 'All';

  final List<_TeamMember> _members = const [
    _TeamMember(name: 'John Doe', email: 'john.doe@tecsys.com', role: 'ADMIN', addedDate: 'Sep 2024'),
    _TeamMember(name: 'Ana Silva', email: 'ana.silva@tecsys.com', role: 'USER', addedDate: 'Oct 2024'),
    _TeamMember(name: 'Carlos Santos', email: 'carlos.s@tecsys.com', role: 'USER', addedDate: 'Nov 2024'),
    _TeamMember(name: 'Mariana Lima', email: 'mariana.l@tecsys.com', role: 'ADMIN', addedDate: 'Jan 2025'),
  ];

  List<_TeamMember> get _filteredMembers {
    return _members.where((member) {
      final matchesSearch = member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          member.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'All' || member.role == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  int get _adminCount => _members.where((m) => m.role == 'ADMIN').length;
  int get _userCount => _members.where((m) => m.role == 'USER').length;

  Future<void> _openAddUser() async {
    final result = await showAddUserDialog(context);
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.fullName} added as ${result.role}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ponto de corte para separar Web/Desktop de Mobile (768 pixéis)
        bool isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return _UsersWebView(
            members: _members,
            filteredMembers: _filteredMembers,
            searchQuery: _searchQuery,
            selectedRole: _selectedRole,
            adminCount: _adminCount,
            userCount: _userCount,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            onRoleChanged: (val) => setState(() => _selectedRole = val ?? 'All'),
            onAddUser: _openAddUser,
          );
        } else {
          return _UsersMobileView(
            members: _members,
            filteredMembers: _filteredMembers,
            searchQuery: _searchQuery,
            selectedRole: _selectedRole,
            adminCount: _adminCount,
            userCount: _userCount,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            onRoleChanged: (val) => setState(() => _selectedRole = val ?? 'All'),
            onAddUser: _openAddUser,
          );
        }
      },
    );
  }
}

/// ==========================================
/// VISTA WEB / DESKTOP (Ecrãs Largos)
/// ==========================================
class _UsersWebView extends StatelessWidget {
  final List<_TeamMember> members;
  final List<_TeamMember> filteredMembers;
  final String searchQuery;
  final String selectedRole;
  final int adminCount;
  final int userCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onAddUser;

  const _UsersWebView({
    required this.members,
    required this.filteredMembers,
    required this.searchQuery,
    required this.selectedRole,
    required this.adminCount,
    required this.userCount,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onAddUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
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
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Users Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                            Text('Tecsys B2B Admin Console', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: onAddUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                      label: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _StatPill(label: 'Total', value: '${members.length}', color: const Color(0xFF0F172A))),
                    const SizedBox(width: 12),
                    Expanded(child: _StatPill(label: 'Admins', value: '$adminCount', color: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatPill(label: 'Users', value: '$userCount', color: const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: TextField(
                          onChanged: onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search members...',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          icon: const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF64748B)),
                          items: ['All', 'ADMIN', 'USER'].map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            );
                          }).toList(),
                          onChanged: onRoleChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'TEAM MEMBERS (${filteredMembers.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
                ),
                const SizedBox(height: 12),
                if (filteredMembers.isEmpty)
                  const _EmptyState()
                else
                  for (final member in filteredMembers) ...[
                    _MemberCard(member: member),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================================
/// VISTA MOBILE (Ecrãs Estreitos)
/// ==========================================
class _UsersMobileView extends StatelessWidget {
  final List<_TeamMember> members;
  final List<_TeamMember> filteredMembers;
  final String searchQuery;
  final String selectedRole;
  final int adminCount;
  final int userCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onAddUser;

  const _UsersMobileView({
    required this.members,
    required this.filteredMembers,
    required this.searchQuery,
    required this.selectedRole,
    required this.adminCount,
    required this.userCount,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onAddUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddUser,
        backgroundColor: AppColors.primary,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
        label: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Users Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                      Text('Tecsys B2B Admin', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _StatPill(label: 'Total', value: '${members.length}', color: const Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Expanded(child: _StatPill(label: 'Admins', value: '$adminCount', color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: _StatPill(label: 'Users', value: '$userCount', color: const Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                      value: selectedRole,
                      icon: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
                      items: ['All', 'ADMIN', 'USER'].map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        );
                      }).toList(),
                      onChanged: onRoleChanged,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'TEAM MEMBERS (${filteredMembers.length})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            if (filteredMembers.isEmpty)
              const _EmptyState()
            else
              for (final member in filteredMembers) ...[
                _MemberCard(member: member),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// WIDGETS AUXILIARES
/// ==========================================
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
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.search_off_rounded, size: 24, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          const Text('No members found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          const SizedBox(height: 2),
          const Text('Try a different search or filter', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final _TeamMember member;

  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.role == 'ADMIN';
    final accent = isAdmin ? AppColors.primary : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isAdmin ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                            child: Text(
                              member.initials,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isAdmin ? AppColors.primary : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text(member.email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAdmin ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              member.role,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isAdmin ? AppColors.primary : const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text('Added ${member.addedDate}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Row(
                            children: [
                              _ActionButton(icon: Icons.edit_outlined, color: const Color(0xFF64748B), onTap: () {}),
                              const SizedBox(width: 6),
                              _ActionButton(icon: Icons.delete_outline_rounded, color: const Color(0xFFEF4444), onTap: () {}),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}