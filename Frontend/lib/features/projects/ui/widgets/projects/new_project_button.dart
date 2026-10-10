import 'package:flutter/material.dart';

import 'package:tecsys_app/core/widgets/primary_action_button.dart';

/// Botão "Novo Projeto". [full] = largura total (mobile).
class NewProjectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool full;

  const NewProjectButton(
      {super.key, required this.onPressed, required this.full});

  @override
  Widget build(BuildContext context) {
    return PrimaryActionButton(
      label: 'Novo Projeto',
      icon: Icons.add,
      onPressed: onPressed,
      full: full,
    );
  }
}
