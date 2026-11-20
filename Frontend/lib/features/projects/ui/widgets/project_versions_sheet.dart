import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/constants/map_filter_options.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';

/// Histórico de versões do projeto (CA4 da US #19), lido de
/// GET /projects/{id}/history (#TG-85): cada recálculo é uma versão, com a
/// data e os filtros usados. A mais recente vem primeiro.
///
/// Dá para voltar a qualquer versão ("Voltar para esta versão"): ela passa a
/// ser a versão em uso e o projeto recalcula com ela. Nenhuma versão é
/// criada nem apagada, então também dá para avançar de novo.
class ProjectVersionsSheet extends StatefulWidget {
  final List<ProjectVersion> versoes;

  /// Restaura a versão e devolve o projeto atualizado; null = sem o botão
  /// (ex.: cálculo em andamento).
  final Future<Project> Function(ProjectVersion)? onRestaurar;

  /// Por que não dá para restaurar agora (mostrado no lugar do botão).
  final String? motivoSemRestaurar;

  const ProjectVersionsSheet({
    super.key,
    required this.versoes,
    this.onRestaurar,
    this.motivoSemRestaurar,
  });

  /// Busca o histórico e mostra numa folha de baixo para cima. Devolve o
  /// projeto quando uma versão foi restaurada (ele já está recalculando).
  static Future<Project?> mostrar(BuildContext context, Project project,
      {ProjectsService? service, bool podeRestaurar = true}) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = service ?? ProjectsService();
    try {
      final versoes = await api.historico(project.id);
      await IbgeService().precarregar();
      if (!context.mounted) return null;
      final restaurado = await showModalBottomSheet<Project>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => ProjectVersionsSheet(
          versoes: versoes,
          onRestaurar: podeRestaurar
              ? (v) => api.restaurarVersao(project.id, v.id)
              : null,
          motivoSemRestaurar: podeRestaurar
              ? null
              : 'Aguarde o cálculo atual terminar para voltar a uma versão.',
        ),
      );
      if (restaurado != null) ProjectsStore.instance.atualizar(restaurado);
      return restaurado;
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Não foi possível carregar as versões agora.')));
      return null;
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
  State<ProjectVersionsSheet> createState() => _ProjectVersionsSheetState();
}

class _ProjectVersionsSheetState extends State<ProjectVersionsSheet> {
  /// Versão sendo restaurada (mostra o carregamento no botão dela).
  int? _restaurando;
  String? _erro;

  Future<void> _restaurar(ProjectVersion v, int numero) async {
    final restaurar = widget.onRestaurar;
    if (restaurar == null || _restaurando != null) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Voltar para a versão $numero?'),
        content: const Text(
            'Ela passa a ser a versão em uso e o projeto é recalculado com a '
            'área e os filtros dela. As outras versões continuam salvas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              key: const Key('confirmar-restaurar'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Voltar para esta versão')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    setState(() {
      _restaurando = v.id;
      _erro = null;
    });
    try {
      final projeto = await restaurar(v);
      if (mounted) Navigator.of(context).pop(projeto);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restaurando = null;
        _erro = 'Não foi possível voltar para a versão $numero. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final versoes = widget.versoes;
    final podeRestaurar = widget.onRestaurar != null;
    final emUso = ProjectVersion.indiceEmUso(versoes);
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
                  : 'Cada recálculo gera uma versão. O relatório mostra a '
                      'versão em uso; dá para voltar a outra versão.',
              style: AppTextStyles.bodySmallMuted,
            ),
            if (versoes.length > 1 && widget.motivoSemRestaurar != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(widget.motivoSemRestaurar!,
                  key: const Key('motivo-sem-restaurar'),
                  style: AppTextStyles.bodySmallMuted),
            ],
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_erro!, style: AppTextStyles.bodySmallError),
            ],
            for (var i = 0; i < versoes.length; i++) ...[
              const SizedBox(height: AppSpacing.md),
              _CartaoVersao(
                key: Key('versao-${versoes[i].id}'),
                numero: versoes.length - i,
                atual: i == emUso,
                data: ProjectVersionsSheet._data(versoes[i].criadoEm),
                linhas: ProjectVersionsSheet.resumo(versoes[i]),
                restaurando: _restaurando == versoes[i].id,
                onRestaurar: i == emUso || !podeRestaurar
                    ? null
                    : _restaurando != null
                        ? () {}
                        : () => _restaurar(versoes[i], versoes.length - i),
                idVersao: versoes[i].id,
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
  final int idVersao;

  /// Null = sem o botão (versão atual ou restauração indisponível).
  final VoidCallback? onRestaurar;
  final bool restaurando;

  const _CartaoVersao({
    super.key,
    required this.numero,
    required this.atual,
    required this.data,
    required this.linhas,
    required this.idVersao,
    this.onRestaurar,
    this.restaurando = false,
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
                  child: const Text('Em uso',
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
          if (onRestaurar != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: Key('restaurar-versao-$idVersao'),
                onPressed: onRestaurar,
                icon: restaurando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.restore, size: 18),
                label: Text(
                    restaurando ? 'Voltando...' : 'Voltar para esta versão'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
