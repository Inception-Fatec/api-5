import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/constants/map_filter_options.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';

/// Histórico de versões do projeto (CA4 da US #19), lido de
/// GET /projects/{id}/history (#TG-85): cada recálculo é uma versão, com a
/// data e os filtros usados. A mais recente vem primeiro.
class ProjectVersionsSheet extends StatelessWidget {
  final List<ProjectVersion> versoes;

  const ProjectVersionsSheet({super.key, required this.versoes});

  /// Busca o histórico e mostra numa folha de baixo para cima.
  static Future<void> mostrar(BuildContext context, Project project,
      {ProjectsService? service}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final versoes = await (service ?? ProjectsService()).historico(project.id);
      await IbgeService().precarregar();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => ProjectVersionsSheet(versoes: versoes),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Não foi possível carregar as versões agora.')));
    }
  }

  static String _data(DateTime? d) {
    if (d == null) return 'Data desconhecida';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  /// Linhas "Rótulo: valores" com os filtros que a versão usou.
  static List<(String, String)> resumo(ProjectVersion v) {
    String juntar(Iterable<String> xs) => xs.join(', ');
    final areas = SelectedArea.fromGeoJson(v.polygon).length;
    final tensao = v.targetLayers.isEmpty
        ? 'Todos'
        : juntar(v.targetLayers.map(MapFilterOptions.targetLayerLabel));
    return [
      if (v.munCodes.isNotEmpty)
        ('Cidades', IbgeService.rotulosMunicipios(v.munCodes)),
      ('Área desenhada',
          areas == 0 ? 'Nenhuma' : '$areas ${areas == 1 ? 'área' : 'áreas'}'),
      ('Tensão', tensao),
      if (v.bairroNames.isNotEmpty) ('Bairro', juntar(v.bairroNames)),
      if (v.clasSub.isNotEmpty) ('Classe', juntar(v.clasSub)),
      if (v.cnaeCodes.isNotEmpty) ('CNAE', juntar(v.cnaeCodes)),
      if (v.conjCodes.isNotEmpty) ('Conjunto', juntar(v.conjCodes)),
      if (v.subCodes.isNotEmpty) ('Subestação', juntar(v.subCodes)),
      if (v.lista('coverage_layers').isNotEmpty)
        ('Pontos a cobrir',
            juntar(v.lista('coverage_layers').map(MapFilterOptions.camadaLabel))),
      if (v.lista('candidate_layers').isNotEmpty)
        ('Candidatos',
            juntar(v.lista('candidate_layers').map(MapFilterOptions.camadaLabel))),
      if (v.gatewayProfile != null) ('Perfil de gateway', v.gatewayProfile!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          children: [
            Text('Versões do projeto', style: AppTextStyles.dialogTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              versoes.isEmpty
                  ? 'Nenhuma versão salva.'
                  : 'Cada recálculo gera uma versão. O relatório mostra a mais recente.',
              style: AppTextStyles.bodySmallMuted,
            ),
            for (var i = 0; i < versoes.length; i++) ...[
              const SizedBox(height: AppSpacing.md),
              _CartaoVersao(
                numero: versoes.length - i,
                atual: i == 0,
                data: _data(versoes[i].criadoEm),
                linhas: resumo(versoes[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoVersao extends StatelessWidget {
  final int numero;
  final bool atual;
  final String data;
  final List<(String, String)> linhas;

  const _CartaoVersao({
    required this.numero,
    required this.atual,
    required this.data,
    required this.linhas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: atual ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Versão $numero', style: AppTextStyles.cardTitle),
              if (atual) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, borderRadius: AppRadius.xs),
                  child: const Text('Atual',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(data, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          for (final (rotulo, valor) in linhas)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$rotulo: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: valor),
                ]),
                style: AppTextStyles.bodySmallMuted,
              ),
            ),
        ],
      ),
    );
  }
}
