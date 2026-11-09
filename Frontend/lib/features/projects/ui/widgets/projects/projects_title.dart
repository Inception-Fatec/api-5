import 'package:flutter/material.dart';

import 'package:tecsys_app/core/widgets/page_title.dart';

/// "Meus Projetos" + contador de projetos.
class ProjectsTitle extends StatelessWidget {
  final double fontSize;
  final int total;

  const ProjectsTitle({super.key, required this.fontSize, required this.total});

  @override
  Widget build(BuildContext context) {
    return PageTitle(
      title: 'Meus Projetos',
      countLabel: '$total ${total == 1 ? "projeto" : "projetos"}',
      fontSize: fontSize,
    );
  }
}
