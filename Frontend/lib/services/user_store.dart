import 'package:flutter/foundation.dart';

import 'user_model.dart';
import 'user_api_service.dart';

/// Fonte única dos usuários carregados, compartilhada entre as telas.
/// Busca a lista de usuários uma vez e armazena em memória para
/// consultas rápidas por ID (ex: mostrar nome do criador do projeto).
class UserStore extends ChangeNotifier {
  UserStore._();
  static final UserStore instance = UserStore._();

  final UserApiService _service = UserApiService.instance;

  List<AppUser> users = [];
  bool loading = false;
  bool _carregouAlgumaVez = false;

  /// Busca a lista de usuários no backend. Se já tiver carregado
  /// antes, não busca de novo sozinho.
  Future<void> carregar({bool force = false}) async {
    if (loading) return;
    if (_carregouAlgumaVez && !force) return;

    loading = true;
    notifyListeners();

    try {
      users = await _service.listUsers();
      _carregouAlgumaVez = true;
    } catch (_) {
      // Silenciosamente falha — o card de projeto mostrará "Usuário #id"
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Retorna o nome do usuário pelo ID, ou null se não encontrar.
  String? nomeDoUsuario(int id) {
    final user = users.where((u) => u.id == id).firstOrNull;
    return user?.name;
  }
}
