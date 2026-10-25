import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';

/// Fonte única dos projetos carregados, compartilhada entre
/// ProjectsScreen e NewProjectScreen.
///
/// Resolve o problema de um projeto recém-criado não aparecer na
/// hora na tela de Projetos: em vez de cada tela buscar/guardar sua
/// própria lista (o que trava no primeiro fetch se o AppShell mantém
/// as telas vivas ao trocar de aba), as duas leem e escrevem aqui.
/// Depois de criar um projeto, a NewProjectScreen chama [adicionar]
/// e ele já entra na lista antes mesmo de qualquer novo GET.
///
/// Colocar em: lib/services/projects_store.dart
class ProjectsStore extends ChangeNotifier {
  ProjectsStore._() : _service = ProjectsService();
  static final ProjectsStore instance = ProjectsStore._();

  /// Instância isolada, com serviço injetado (só para testes).
  @visibleForTesting
  ProjectsStore.forTesting(ProjectsService service) : _service = service;

  final ProjectsService _service;

  List<Project> projects = [];
  bool loading = false;
  String? erro;
  bool _carregouAlgumaVez = false;

  /// Busca a lista no backend. Se já tiver carregado antes, não
  /// busca de novo sozinho (evita refazer o GET toda vez que a tela
  /// remonta) — passe `force: true` pra recarregar de propósito
  /// (botão "Tentar de novo", pull-to-refresh, etc.).
  Future<void> carregar({bool force = false}) async {
    if (loading) return;
    if (_carregouAlgumaVez && !force) return;

    loading = true;
    erro = null;
    notifyListeners();

    try {
      projects = await _service.listar();
      _carregouAlgumaVez = true;
    } catch (_) {
      erro = 'Não foi possível carregar os projetos agora.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Status em que o motor ainda não terminou (o back/motor muda o status
  /// direto no banco, então só um novo GET descobre que acabou).
  static const statusPendentes = {'CRIADO', 'ENVIADO', 'PROCESSANDO'};

  bool get temPendentes =>
      projects.any((p) => statusPendentes.contains(p.status));

  /// Recarrega a lista sem mostrar loading nem erro (atualização em
  /// segundo plano). Só notifica se algo mudou, para não reconstruir a
  /// tela à toa a cada ciclo.
  Future<void> atualizarSilencioso() async {
    if (loading) return;
    try {
      final novos = await _service.listar();
      if (_mudou(projects, novos)) {
        projects = novos;
        notifyListeners();
      }
    } catch (_) {
      // Mantém a lista atual; o próximo ciclo tenta de novo.
    }
  }

  static bool _mudou(List<Project> a, List<Project> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].status != b[i].status ||
          a[i].name != b[i].name) {
        return true;
      }
    }
    return false;
  }

  /// Insere um projeto recém-criado no topo da lista imediatamente —
  /// sem esperar um novo GET pra ele aparecer na ProjectsScreen.
  void adicionar(Project projeto) {
    projects = [projeto, ...projects];
    notifyListeners();
  }

  /// Exclui de verdade (DELETE /projects/{id}) e já tira da lista
  /// compartilhada se der certo. Deixa o erro estourar pra quem
  /// chamou decidir como avisar o usuário.
  Future<void> excluir(int id) async {
    await _service.excluir(id);
    projects = projects.where((p) => p.id != id).toList();
    notifyListeners();
  }
}
