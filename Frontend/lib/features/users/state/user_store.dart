import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/data/services/user_api_service.dart';

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
  Future<void>? _emAndamento;

  /// Erro da última busca (null se deu certo).
  Object? erro;

  /// Busca a lista de usuários no backend. Se já tiver carregado
  /// antes, não busca de novo sozinho ([force] busca de novo). Se uma
  /// busca já está em andamento, devolve ela em vez de abrir outra —
  /// assim Projetos e Usuários, montadas juntas, fazem uma chamada só.
  Future<void> carregar({bool force = false}) {
    final emAndamento = _emAndamento;
    if (emAndamento != null) return emAndamento;
    if (_carregouAlgumaVez && !force) return Future.value();
    return _emAndamento = _buscar().whenComplete(() => _emAndamento = null);
  }

  Future<void> _buscar() async {
    loading = true;
    erro = null;
    notifyListeners();
    try {
      users = await _service.listUsers();
      _carregouAlgumaVez = true;
    } catch (e) {
      // O card de projeto mostra "Usuário #id"; a tela de Usuários
      // mostra o erro.
      erro = e;
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
