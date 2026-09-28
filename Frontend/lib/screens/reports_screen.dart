import 'package:flutter/material.dart';

import '../services/project_model.dart';
import '../theme/app_theme.dart';
import '../utils/distribuidoras.dart';
import '../widgets/common/page_body.dart';


/// Tela de detalhe do projeto — pra onde o card clicável da
/// ProjectsScreen leva. No fim vai ter o relatório e o mapa com os
/// pontos definidos na Etapa 2 da NewProjectScreen.
///
/// Por enquanto é só uma tela de exemplo, sem nada implementado —
/// existe pra já ter a navegação funcionando e um lugar pra encaixar
/// o conteúdo de verdade depois. Web e mobile mostram o mesmo
/// placeholder (não há diferença de plataforma aqui ainda).
class ProjectDetailScreen extends StatelessWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColor = ProjectStatusStyle.color(project.status);

    return PageBody(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      ProjectStatusStyle.label(project.status),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  'ID #${project.id} • ${nomeDistribuidora(project.distCode)} • ${project.dataFormatada}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.construction_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'Em desenvolvimento',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Aqui vai entrar o relatório do projeto e o mapa com os pontos definidos na Etapa 2 da criação (New Project).',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
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