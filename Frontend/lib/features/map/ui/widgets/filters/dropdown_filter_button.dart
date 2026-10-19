import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';

/// Botão de filtro que abre um painel flutuante (overlay) logo abaixo
/// de si. Fica destacado quando [ativo] ou enquanto o painel está aberto.
class DropdownFilterButton extends StatefulWidget {
  final String label;

  /// Constrói o conteúdo do painel; [fechar] fecha o overlay.
  final Widget Function(BuildContext context, VoidCallback fechar) panelBuilder;

  final bool ativo;
  final IconData? icon;

  const DropdownFilterButton({
    super.key,
    required this.label,
    required this.panelBuilder,
    this.ativo = false,
    this.icon,
  });

  @override
  State<DropdownFilterButton> createState() => _DropdownFilterButtonState();
}

class _DropdownFilterButtonState extends State<DropdownFilterButton> {
  OverlayEntry? _overlay;

  @override
  void didUpdateWidget(covariant DropdownFilterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Painel aberto enquanto o pai reconstrói (ex: marcou uma opção):
    // reconstrói o overlay depois do frame para mostrar o valor novo.
    if (_overlay != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _overlay?.markNeedsBuild());
    }
  }

  void _alternar() {
    if (_overlay != null) {
      _fechar();
    } else {
      _abrir();
    }
    setState(() {});
  }

  /// Posição do painel logo abaixo do botão, mantido dentro da tela.
  (double left, double top, double larguraMaxPainel) _calcularPosicionamento() {
    const margem = FiltersStyles.overlayMargin;
    final tamanhoTela = MediaQuery.of(context).size;
    final larguraMaxPainel = (tamanhoTela.width - margem * 2)
        .clamp(FiltersStyles.overlayMinWidth, FiltersStyles.overlayMaxWidth);

    final caixaBotao = context.findRenderObject() as RenderBox?;
    if (caixaBotao == null || !caixaBotao.attached) {
      return (margem, margem, larguraMaxPainel);
    }

    final posicaoBotao = caixaBotao.localToGlobal(Offset.zero);
    var left = posicaoBotao.dx;
    final top =
        posicaoBotao.dy + caixaBotao.size.height + FiltersStyles.overlayOffsetY;

    final maxLeft = tamanhoTela.width - margem - larguraMaxPainel;
    if (left > maxLeft) left = maxLeft;
    if (left < margem) left = margem;

    return (left, top, larguraMaxPainel);
  }

  void _abrir() {
    final overlayState = Overlay.of(context);

    _overlay = OverlayEntry(
      builder: (context) {
        final (left, top, larguraMaxPainel) = _calcularPosicionamento();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _fechar,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: FiltersStyles.overlayElevation,
                borderRadius: AppRadius.lg,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: larguraMaxPainel,
                    maxHeight: FiltersStyles.overlayMaxHeight,
                  ),
                  child: widget.panelBuilder(context, _fechar),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(_overlay!);
  }

  void _fechar() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aberto = _overlay != null;
    return InkWell(
      onTap: _alternar,
      borderRadius: AppRadius.sm,
      child: Container(
        padding: FiltersStyles.buttonPadding,
        decoration:
            FiltersStyles.buttonDecoration(highlighted: widget.ativo || aberto),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: FiltersStyles.buttonIconSize,
                color:
                    widget.ativo ? AppColors.infoBlue : AppColors.textSecondary,
              ),
              const SizedBox(width: FiltersStyles.gap),
            ],
            Text(
              widget.label,
              style: widget.ativo
                  ? FiltersStyles.buttonLabelActive
                  : FiltersStyles.buttonLabelIdle,
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              aberto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: FiltersStyles.buttonArrowSize,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
