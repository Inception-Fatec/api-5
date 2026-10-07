import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Card de listagem com o visual padrão do app e efeito de hover (sobe
/// e ganha sombra com o mouse por cima; no toque não muda nada).
class HoverCard extends StatefulWidget {
  final Widget child;

  /// Mostra o cursor de clique (use false em cards que não são tocáveis).
  final bool clickable;

  const HoverCard({super.key, required this.child, this.clickable = true});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.clickable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppDecorations.cardAnimation,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
            0, _hover ? AppDecorations.cardHoverLift : 0, 0),
        decoration: AppDecorations.card(hover: _hover),
        child: widget.child,
      ),
    );
  }
}
