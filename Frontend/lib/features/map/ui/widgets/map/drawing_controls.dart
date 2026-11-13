import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/state/desenho_poligono.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Forma da área desenhada (#TG-146).
enum ModoDesenho { poligono, retangulo }

/// Barra do modo de seleção de área: escolhe Polígono ou Retângulo, mostra
/// a dica do que fazer e, no polígono, Desfazer / Cancelar / Concluir.
class DrawingControls extends StatelessWidget {
  final ModoDesenho modo;
  final ValueChanged<ModoDesenho> onModo;
  final DesenhoPoligono desenho;
  final VoidCallback onDesfazer;
  final VoidCallback onCancelar;
  final VoidCallback onConcluir;

  const DrawingControls({
    super.key,
    required this.modo,
    required this.onModo,
    required this.desenho,
    required this.onDesfazer,
    required this.onCancelar,
    required this.onConcluir,
  });

  static String dica(ModoDesenho modo, int vertices) {
    if (modo == ModoDesenho.retangulo)
      return 'Arraste para selecionar uma área';
    if (vertices == 0) return 'Clique no mapa para marcar o 1º vértice';
    if (vertices < SelectedArea.minVertices) {
      final faltam = SelectedArea.minVertices - vertices;
      return 'Marque mais $faltam vértice${faltam == 1 ? '' : 's'}';
    }
    return 'Clique no 1º vértice, dê duplo clique ou toque em Concluir';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: desenho,
      builder: (context, _) {
        final poligono = modo == ModoDesenho.poligono;
        final area = desenho.areaKm2;
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          decoration: MapStyles.selectionHintDecoration.copyWith(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  SegmentedButton<ModoDesenho>(
                    showSelectedIcon: false,
                    style: _estiloSegmento,
                    segments: const [
                      ButtonSegment(
                        value: ModoDesenho.poligono,
                        icon: Icon(Icons.polyline_outlined, size: 16),
                        label: Text('Polígono'),
                      ),
                      ButtonSegment(
                        value: ModoDesenho.retangulo,
                        icon: Icon(Icons.crop_square_rounded, size: 16),
                        label: Text('Retângulo'),
                      ),
                    ],
                    selected: {modo},
                    onSelectionChanged: (s) => onModo(s.first),
                  ),
                  if (poligono) ...[
                    _Botao(
                      icon: Icons.undo_rounded,
                      texto: 'Desfazer',
                      tooltip: 'Desfazer último ponto (Backspace)',
                      onTap: desenho.vazio ? null : onDesfazer,
                    ),
                    _Botao(
                      icon: Icons.close_rounded,
                      texto: 'Cancelar',
                      tooltip: 'Cancelar desenho (Esc)',
                      onTap: desenho.vazio ? null : onCancelar,
                    ),
                    _Botao(
                      icon: Icons.check_rounded,
                      texto: 'Concluir',
                      tooltip: desenho.podeConcluir
                          ? 'Concluir área (Enter)'
                          : 'Marque pelo menos ${SelectedArea.minVertices} vértices',
                      destaque: true,
                      onTap: desenho.podeConcluir ? onConcluir : null,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  dica(modo, desenho.total),
                  if (poligono && area != null) '${_km2(area)} km²',
                ].join('  ·  '),
                textAlign: TextAlign.center,
                style: MapStyles.selectionHintText.copyWith(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _km2(double v) =>
      v.toStringAsFixed(v < 10 ? 2 : 1).replaceAll('.', ',');

  static final _estiloSegmento = ButtonStyle(
    visualDensity: VisualDensity.compact,
    textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    foregroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppColors.onPrimary
            : Colors.white70),
    backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? MapStyles.corArea
            : Colors.transparent),
    side: const WidgetStatePropertyAll(BorderSide(color: Colors.white24)),
  );
}

class _Botao extends StatelessWidget {
  final IconData icon;
  final String texto;
  final String tooltip;
  final VoidCallback? onTap;
  final bool destaque;

  const _Botao({
    required this.icon,
    required this.texto,
    required this.tooltip,
    required this.onTap,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = onTap != null;
    final cor = destaque ? MapStyles.selectionConfirmColor : Colors.white24;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(texto),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: AppColors.onPrimary,
          disabledForegroundColor: Colors.white38,
          backgroundColor: ativo && destaque ? cor : Colors.transparent,
          side: BorderSide(color: ativo ? cor : Colors.white12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
