import 'package:flutter/material.dart';

import 'package:tecsys_app/core/widgets/app_search_field.dart';

/// Campo de busca da lista de projetos.
class ProjectsSearchField extends StatelessWidget {
  final String initialText;
  final ValueChanged<String> onChanged;

  const ProjectsSearchField(
      {super.key, this.initialText = '', required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      hint: 'Buscar por nome do projeto ou empresa...',
      initialText: initialText,
      onChanged: onChanged,
    );
  }
}
