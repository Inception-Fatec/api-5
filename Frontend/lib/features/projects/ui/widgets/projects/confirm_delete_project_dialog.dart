import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Pergunta se o usuário quer mesmo excluir o projeto. Devolve true
/// só se ele confirmar.
Future<bool> confirmDeleteProject(
    BuildContext context, String projectName) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir projeto'),
      content: Text(
          'Tem certeza que deseja excluir "$projectName"? Essa ação não pode ser desfeita.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child:
              const Text('Excluir', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  return confirmar == true;
}
