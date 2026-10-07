import 'package:flutter/material.dart';

/// Rótulo e cores de cada status de projeto (só apresentação — o
/// model [Project] guarda apenas o status cru vindo do backend).
class ProjectStatusStyle {
  ProjectStatusStyle._();

  static String label(String status) {
    switch (status) {
      case 'CRIADO':
        return 'Criado';
      case 'ENVIADO':
        return 'Enviado';
      case 'PROCESSANDO':
        return 'Processando';
      case 'SUCESSO':
        return 'Concluído';
      case 'FALHA':
        return 'Falha';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'SUCESSO':
        return const Color(0xFF1E9E5A);
      case 'FALHA':
        return const Color(0xFFD64545);
      case 'PROCESSANDO':
        return const Color(0xFFE0A72E);
      case 'ENVIADO':
        return const Color(0xFF3A7BD5);
      case 'CRIADO':
      default:
        return const Color(0xFF8A93A6);
    }
  }

  /// Fundo suave do badge: a mesma cor de [color] a 12% de opacidade
  /// (pré-calculada, no lugar do antigo `withOpacity(0.12)`).
  static Color softColor(String status) {
    switch (status) {
      case 'SUCESSO':
        return const Color(0x1F1E9E5A);
      case 'FALHA':
        return const Color(0x1FD64545);
      case 'PROCESSANDO':
        return const Color(0x1FE0A72E);
      case 'ENVIADO':
        return const Color(0x1F3A7BD5);
      case 'CRIADO':
      default:
        return const Color(0x1F8A93A6);
    }
  }
}
