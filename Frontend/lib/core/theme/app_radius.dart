import 'package:flutter/material.dart';

/// Raios de borda padronizados (os valores já usados nas telas).
class AppRadius {
  AppRadius._();

  static const xs = BorderRadius.all(Radius.circular(8));
  static const sm = BorderRadius.all(Radius.circular(10));
  static const md = BorderRadius.all(Radius.circular(12)); // campos, botões
  static const lg =
      BorderRadius.all(Radius.circular(14)); // cards, botões grandes
  static const xl =
      BorderRadius.all(Radius.circular(16)); // cards destacados, diálogos
  static const xxl = BorderRadius.all(Radius.circular(20)); // ripple de ícones
  static const pill = BorderRadius.all(Radius.circular(100));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(20));
}
