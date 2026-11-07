import 'package:flutter/material.dart';

/// Fonte única dos itens de navegação. BottomNavBar, TopNavBar e o
/// AppShell leem daqui -- mudar um label/ícone muda nos dois lugares
/// (paridade web/mobile).
///
/// "Novo Projeto" DEIXOU de ser uma aba própria -- virou só o botão
/// dentro de "Projetos" (que já abre o popup direto, sem precisar de
/// tela/aba dedicada). O "Nenhum projeto em andamento" que ficava
/// nessa aba também migrou pra ser o estado vazio da lista de
/// Projetos.
///
/// RN04 (US-34): "Users" e "ETL & Geodados" só aparecem pra quem está
/// logado como ADM (o backend exige ADM em /users e /etl) --
/// por isso deixou de ser uma lista 'const' fixa e virou [forRole],
/// que recebe o role atual (AuthService.instance.role) e monta a
/// lista certa. "Login"/conta continua sempre por último: o AppShell
/// trata o último índice como ação especial (abre o menu de conta),
/// nunca uma aba -- isso não muda com o Users entrando no meio.
class NavItems {
  NavItems();

  static const projects = (icon: Icons.folder_outlined, label: 'Projetos');
  static const users = (icon: Icons.people_outline, label: 'Usuários');
  static const etlGeodados = (icon: Icons.storage_outlined, label: 'ETL & Geodados');
  static const _account = (icon: Icons.account_circle_outlined, label: 'Conta');

  static List<({IconData icon, String label})> forRole(String? role) {
    return [
      projects,
      if (role == 'ADM') users,
      if (role == 'ADM') etlGeodados,
      _account,
    ];
  }
}