/// Espelha UserRole (backend) e UserResponseDto — usado pela tela de
/// gestão de usuários (US-34) e pelo AddUserDialog.
enum UserRoleType { adm, user }

extension UserRoleTypeX on UserRoleType {
  /// Valor que vai no corpo do request (bate com o enum Java UserRole).
  String get apiValue => this == UserRoleType.adm ? 'ADM' : 'USER';

  /// Label exibido na UI (mesmo texto do protótipo original: ADMIN/USER).
  String get label => this == UserRoleType.adm ? 'ADMIN' : 'USER';

  static UserRoleType fromApi(String value) {
    return value.toUpperCase() == 'ADM' ? UserRoleType.adm : UserRoleType.user;
  }
}

/// Espelha UserResponseDto (id, name, email, role) — o backend não
/// devolve password_hash nem must_change_password nessa rota.
class AppUser {
  final int id;
  final String name;
  final String email;
  final UserRoleType role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRoleTypeX.fromApi(json['role'] as String),
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}