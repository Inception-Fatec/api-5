import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DropdownFilterButton extends StatefulWidget {
  const DropdownFilterButton({
    super.key,
    required this.label,
    required this.panelBuilder,
    this.ativo = false,
    this.icon,
  });

  final String label;

  final Widget Function(BuildContext context, VoidCallback fechar) panelBuilder;

  final bool ativo;

  final IconData? icon;

  @override
  State<DropdownFilterButton> createState() => _DropdownFilterButtonState();
}

class _DropdownFilterButtonState extends State<DropdownFilterButton> {
  OverlayEntry? _overlay;

  @override
  void didUpdateWidget(covariant DropdownFilterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _overlay?.markNeedsBuild());
    }
  }

  void _alternar() {
    if (_overlay != null) {
      _fechar();
    } else {
      _abrir();
    }
  }
  (double left, double top, double larguraMaxPainel) _calcularPosicionamento() {
    const margem = 12.0;
    final tamanhoTela = MediaQuery.of(context).size;
    final larguraMaxPainel = (tamanhoTela.width - margem * 2).clamp(200.0, 320.0);

    final caixaBotao = context.findRenderObject() as RenderBox?;
    if (caixaBotao == null || !caixaBotao.attached) {
      return (margem, margem, larguraMaxPainel);
    }

    final posicaoBotao = caixaBotao.localToGlobal(Offset.zero);
    var left = posicaoBotao.dx;
    final top = posicaoBotao.dy + caixaBotao.size.height + 6;

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
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: larguraMaxPainel, maxHeight: 420),
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
      onTap: () {
        _alternar();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: (widget.ativo || aberto) ? AppColors.infoBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: (widget.ativo || aberto) ? AppColors.infoBlue : const Color(0xFFE4E8EF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 15, color: widget.ativo ? AppColors.infoBlue : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(widget.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.ativo ? FontWeight.w700 : FontWeight.w500,
                    color: widget.ativo ? AppColors.infoBlue : AppColors.textPrimary)),
            const SizedBox(width: 4),
            Icon(aberto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}