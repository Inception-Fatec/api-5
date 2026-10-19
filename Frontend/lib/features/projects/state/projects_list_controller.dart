import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/core/utils/text_normalizer.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';
import 'package:tecsys_app/features/users/state/user_store.dart';

/// Estado da tela "Meus Projetos": a lista de verdade vive no
/// [ProjectsStore] (compartilhado com a tela de Novo Projeto); aqui
/// ficam a busca, as métricas e os helpers de exibição.
class ProjectsListController extends ChangeNotifier {
  ProjectsListController({ProjectsStore? store, UserStore? userStore})
      : _store = store ?? ProjectsStore.instance,
        _userStore = userStore ?? UserStore.instance {
    _store.addListener(notifyListeners);
  }

  final ProjectsStore _store;
  final UserStore _userStore;

  String _busca = '';

  /// Texto atual da busca (pra o campo recuperar o que foi digitado se a
  /// tela trocar de layout web/mobile e o campo for recriado).
  String get busca => _busca;

  List<Project> get projects => _store.projects;
  bool get loading => _store.loading;
  String? get erro => _store.erro;

  /// Carga inicial (o store ignora se já carregou antes).
  void carregarInicial() {
    _store.carregar();
    _userStore.carregar();
  }

  Future<void> recarregar() => _store.carregar(force: true);

  void setBusca(String valor) {
    _busca = valor;
    notifyListeners();
  }

  // Busca simples e tolerante a acento (mesma normalização do resto
  // do app) — nome do projeto ou nome/código da empresa, ignorando
  // maiúscula/minúscula e acentos.
  List<Project> get projetosFiltrados {
    final termo = normalizarTexto(_busca.trim()).toLowerCase();
    if (termo.isEmpty) return _store.projects;
    return _store.projects.where((p) {
      final nomeProjeto = normalizarTexto(p.name).toLowerCase();
      final nomeEmpresa =
          normalizarTexto(nomeDistribuidora(p.distCode)).toLowerCase();
      return nomeProjeto.contains(termo) ||
          nomeEmpresa.contains(termo) ||
          p.distCode.toLowerCase().contains(termo);
    }).toList();
  }

  int get totalProjetos => _store.projects.length;

  // TODO: por enquanto igual ao total de projetos. A lógica real de
  // "calculado" vai bater o status de cada projeto com o backend
  // (relatório pronto) quando esse fluxo existir.
  int get totalCalculados => _store.projects.length;

  /// Exclui de verdade; deixa o erro estourar pra quem chamou avisar.
  Future<void> excluir(int id) => _store.excluir(id);

  /// Nome do criador, ou "Usuário #id" se o usuário não foi carregado.
  String nomeCriador(int userId) =>
      _userStore.nomeDoUsuario(userId) ?? 'Usuário #$userId';

  @override
  void dispose() {
    _store.removeListener(notifyListeners);
    super.dispose();
  }
}
