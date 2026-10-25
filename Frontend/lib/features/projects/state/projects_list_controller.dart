import 'dart:async';

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
  String? _statusFiltro;
  Timer? _timer;

  /// Texto atual da busca (pra o campo recuperar o que foi digitado se a
  /// tela trocar de layout web/mobile e o campo for recriado).
  String get busca => _busca;

  List<Project> get projects => _store.projects;
  bool get loading => _store.loading;
  String? get erro => _store.erro;

  /// Status escolhido no filtro (null = todos).
  String? get statusFiltro => _statusFiltro;

  /// Carga inicial (o store ignora se já carregou antes) e início da
  /// atualização automática.
  void carregarInicial() {
    _store.carregar();
    _userStore.carregar();
    iniciarAtualizacaoAutomatica();
  }

  /// Enquanto houver projeto calculando (CRIADO/ENVIADO/PROCESSANDO),
  /// consulta a lista a cada [intervalo] para refletir o fim do cálculo.
  /// Sem pendentes não faz requisição nenhuma.
  void iniciarAtualizacaoAutomatica(
      {Duration intervalo = const Duration(seconds: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) {
      if (_store.temPendentes) _store.atualizarSilencioso();
    });
  }

  Future<void> recarregar() => _store.carregar(force: true);

  void setBusca(String valor) {
    _busca = valor;
    notifyListeners();
  }

  void setStatusFiltro(String? status) {
    _statusFiltro = status;
    notifyListeners();
  }

  /// Quantos projetos há em cada status (para os chips do filtro).
  int contagemStatus(String? status) => status == null
      ? _store.projects.length
      : _store.projects.where((p) => p.status == status).length;

  // Busca simples e tolerante a acento (mesma normalização do resto
  // do app) — nome do projeto ou nome/código da empresa, ignorando
  // maiúscula/minúscula e acentos.
  List<Project> get projetosFiltrados {
    final termo = normalizarTexto(_busca.trim()).toLowerCase();
    final porStatus = _statusFiltro == null
        ? _store.projects
        : _store.projects.where((p) => p.status == _statusFiltro).toList();
    if (termo.isEmpty) return porStatus;
    return porStatus.where((p) {
      final nomeProjeto = normalizarTexto(p.name).toLowerCase();
      final nomeEmpresa =
          normalizarTexto(nomeDistribuidora(p.distCode)).toLowerCase();
      return nomeProjeto.contains(termo) ||
          nomeEmpresa.contains(termo) ||
          p.distCode.toLowerCase().contains(termo);
    }).toList();
  }

  int get totalProjetos => _store.projects.length;

  /// Projetos com cálculo concluído (status SUCESSO).
  int get totalCalculados => contagemStatus('SUCESSO');

  /// Exclui de verdade; deixa o erro estourar pra quem chamou avisar.
  Future<void> excluir(int id) => _store.excluir(id);

  /// Nome do criador, ou "Usuário #id" se o usuário não foi carregado.
  String nomeCriador(int userId) =>
      _userStore.nomeDoUsuario(userId) ?? 'Usuário #$userId';

  @override
  void dispose() {
    _timer?.cancel();
    _store.removeListener(notifyListeners);
    super.dispose();
  }
}
