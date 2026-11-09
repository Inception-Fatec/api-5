import 'package:flutter/material.dart';

import '../etl_theme.dart';

/// Botão verde principal (bg-teal-600, hover teal-700, rounded-xl).
class EtlPrimaryButton extends StatefulWidget {
  const EtlPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 18,
    this.fontSize = 14,
    this.gap = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.shadowColor = EtlColors.teal700Shadow10,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final double fontSize;
  final double gap;
  final EdgeInsets padding;
  final Color shadowColor;

  @override
  State<EtlPrimaryButton> createState() => _EtlPrimaryButtonState();
}

class _EtlPrimaryButtonState extends State<EtlPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color bg = !enabled
        ? EtlColors.teal400
        : (_hover ? EtlColors.teal700 : EtlColors.teal600);
    final double lh = widget.fontSize >= 14 ? 20 : 16;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: widget.shadowColor, blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.iconSize, color: Colors.white),
                SizedBox(width: widget.gap),
              ],
              Text(
                widget.label,
                style: etlText(widget.fontSize,
                    weight: FontWeight.w600, color: Colors.white, lineHeight: lh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão secundário "Cancelar" (borda slate-200, texto slate-600).
class EtlOutlineButton extends StatefulWidget {
  const EtlOutlineButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<EtlOutlineButton> createState() => _EtlOutlineButtonState();
}

class _EtlOutlineButtonState extends State<EtlOutlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EtlColors.slate200),
            boxShadow: const [
              BoxShadow(color: EtlColors.black5, blurRadius: 1, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            widget.label,
            style: etlText(
              12,
              weight: FontWeight.w600,
              color: _hover && enabled ? EtlColors.slate900 : EtlColors.slate600,
              lineHeight: 16,
            ),
          ),
        ),
      ),
    );
  }
}
