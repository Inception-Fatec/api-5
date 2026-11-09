import 'package:flutter/material.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/map/ui/screens/points_map_screen.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';

/// Abre um projeto salvo no mapa com a área, os filtros e as cidades da
/// última versão do histórico (#TG-86), para ajustar e recalcular.
/// Usado pelo relatório e pelos Recentes (#TG-88).
///
/// Devolve o projeto atualizado (status Enviado) se o usuário recalculou,
/// para quem chamou abrir o relatório dele; null se só olhou e voltou.
/// Problemas (sem histórico, erro de rede) viram um aviso na tela.
Future<Project?> abrirProjetoNoMapa(
  BuildContext context,
  Project project, {
  ProjectsService? service,
}) async {
  void avisar(String mensagem) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  try {
    final versoes = await (service ?? ProjectsService()).historico(project.id);
    if (versoes.isEmpty) {
      avisar('Este projeto não tem área nem filtros salvos para abrir.');
      return null;
    }
    final versao = versoes.first;
    await IbgeService().precarregar();
    final codigos =
        versao.munCodes.isNotEmpty ? versao.munCodes : project.munCodes;
    if (!context.mounted) return null;

    final recalculou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PointsMapScreen(
          nomeProjeto: project.name,
          distCode: project.distCode,
          distribuidoraLabel: nomeDistribuidora(project.distCode),
          municipios: codigos.map(IbgeService.municipioPorCodigo).toList(),
          projetoId: project.id,
          versaoInicial: versao,
        ),
      ),
    );
    if (recalculou != true) return null;
    // O mapa já pôs a versão recalculada no store (status Enviado).
    return ProjectsStore.instance.projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project.copyWith(status: 'ENVIADO'),
    );
  } catch (_) {
    avisar('Não foi possível abrir o projeto no mapa agora.');
    return null;
  }
}
