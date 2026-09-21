import 'package:flutter/material.dart';

/// Envolve o conteúdo de uma tela num [Material] transparente. As
/// telas-conteúdo (ProjectsScreen, NewProjectScreen, MapScreen) não
/// têm Scaffold próprio — normalmente ganham um Material ancestral de
/// graça pelo Scaffold do AppShell. Mas se algum dia uma delas for
/// alcançada por fora do Shell (ex: um Navigator.push direto, antes
/// de trocarmos esses botões por AppShell.of(context)?.goToTab),
/// ela ainda funciona sem o erro "No Material widget found" em
/// TextField/DropdownButton/InkWell.
class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: child);
  }
}