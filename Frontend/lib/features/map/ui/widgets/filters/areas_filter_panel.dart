import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';


class AreasFilterPanel extends StatelessWidget {
  final List<SelectedArea> areas;

  /// Índice da área selecionada (cartão destacado), ou null.
  final int? selecionada;

  /// Pontos dentro da área com os filtros atuais; null = ainda contando.
  final int? Function(SelectedArea area) totalDe;

  final ValueChanged<int> onFocar;
  final ValueChanged<int> onRemover;
  final VoidCallback onLimpar;

  const AreasFilterPanel({
    super.key,
    required this.areas,
    required this.totalDe,
    this.selecionada,
    required this.onFocar,
    required this.onRemover,
    required this.onLimpar,
  });

  static String _pontos(int? total) {
    if (total == null) return 'contando…';
    return total == 1 ? '1 ponto' : '$total pontos';
  }

  static String _km(double v) =>
      v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',');

  static String _tamanho(SelectedArea a) =>
      '${_km(a.widthKm)} × ${_km(a.heightKm)} km';

  static String _coordenadas(SelectedArea a) {
    String f(double v) => v.toStringAsFixed(4);
    return '${f(a.north)}, ${f(a.west)}  →  ${f(a.south)}, ${f(a.east)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: FiltersStyles.areasPanelPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalho(),
          const SizedBox(height: FiltersStyles.areaCardGap),
          if (areas.isEmpty)
            const _Vazio()
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < areas.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: FiltersStyles.areaCardGap),
                        child: _CartaoArea(
                          numero: i + 1,
                          selecionada: i == selecionada,
                          titulo: 'Área ${i + 1}  ·  ${_pontos(totalDe(areas[i]))}',
                          coordenadas:
                              '${_tamanho(areas[i])}  ·  ${_coordenadas(areas[i])}',
                          onTap: () => onFocar(i),
                          onRemover: () => onRemover(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Row(
      children: [
        const Text('Áreas', style: FiltersStyles.areasHeaderTitle),
        if (areas.isNotEmpty) ...[
          const SizedBox(width: FiltersStyles.gap),
          Container(
            padding: FiltersStyles.areasCountPadding,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withOpacity(FiltersStyles.areasCountBgOpacity),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text('${areas.length}', style: FiltersStyles.areasCountText),
          ),
        ],
        const Spacer(),
        if (areas.isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.textSecondary,
            ),
            onPressed: onLimpar,
            child: const Text('Limpar', style: FiltersStyles.areasClearText),
          ),
      ],
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: FiltersStyles.areasEmptyPadding,
      decoration: const BoxDecoration(
        color: FiltersStyles.areasEmptyBg,
        borderRadius: AppRadius.sm,
      ),
      child: const Column(
        children: [
          Icon(Icons.highlight_alt,
              size: FiltersStyles.areasEmptyIconSize,
              color: AppColors.textSecondary),
          SizedBox(height: FiltersStyles.gap),
          Text(
            'Nenhuma área selecionada.\nUse a ferramenta de seleção no mapa.',
            textAlign: TextAlign.center,
            style: FiltersStyles.areasEmptyText,
          ),
        ],
      ),
    );
  }
}

class _CartaoArea extends StatelessWidget {
  final int numero;
  final bool selecionada;
  final String titulo;
  final String coordenadas;
  final VoidCallback onTap;
  final VoidCallback onRemover;

  const _CartaoArea({
    required this.numero,
    required this.selecionada,
    required this.titulo,
    required this.coordenadas,
    required this.onTap,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionada
          ? AppColors.primary
              .withOpacity(FiltersStyles.areaCardSelectedBgOpacity)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sm,
        side: BorderSide(
          color: selecionada ? AppColors.primary : AppColors.border,
          width: selecionada ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.sm,
        onTap: onTap,
        child: Padding(
          padding: FiltersStyles.areaCardPadding,
          child: Row(
            children: [
              Container(
                width: FiltersStyles.areaBadgeSize,
                height: FiltersStyles.areaBadgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withOpacity(FiltersStyles.areasCountBgOpacity),
                  shape: BoxShape.circle,
                ),
                child: Text('$numero', style: FiltersStyles.areaBadgeText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: FiltersStyles.areaTitle),
                    const SizedBox(height: 2),
                    Text(
                      coordenadas,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FiltersStyles.areaCoords,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded,
                    size: FiltersStyles.areaRemoveIconSize,
                    color: AppColors.textSecondary),
                onPressed: onRemover,
              ),
            ],
          ),
        ),
      ),
    );
  }
}