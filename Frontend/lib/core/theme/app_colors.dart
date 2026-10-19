import 'package:flutter/material.dart';

/// Paleta única do app. Nenhuma tela deve declarar `Color(0x...)`,
/// `Colors.xxx` ou `withOpacity` por conta própria: se faltar uma
/// cor, ela entra aqui.
class AppColors {
  AppColors._();

  // --- Base (spec original da tela de Login) ---------------------------
  static const primary = Color(0xFF006A60); // Sign In button / links / icons
  static const textPrimary = Color(0xFF191A2B);
  static const textSecondary = Color(0xFF8A94A6);
  static const background = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF0F3F9);
  static const badgeBg = Color(0xFFF0F3F9);
  static const chipBg = Color(0xFFEAF0FE); // "Deployment 01" pill
  static const pageBg = Color(0xFFF8F9FA); // map screen background
  static const infoBlue = Color(0xFF2F80ED); // layer/GPS icons, RSSI badge
  static const infoBlueBg = Color(0xFFE3EEFC);
  static const coverageFill = Color(0x402F8FE0);
  static const coverageBorder = Color(0xFF2F8FE0);
  static const success = Color(0xFF1FA971); // CONNECTED / Excellent link

  // --- Superfícies e contornos -------------------------------------------
  static const surface = Color(0xFFFFFFFF); // fundo de cards
  static const onPrimary = Color(0xFFFFFFFF); // texto/ícone sobre primary
  static const border = Color(0xFFE4E8EF); // contorno de cards/campos
  static const divider = Color(0xFFEDEFF3); // linhas separadoras

  // --- Estados -----------------------------------------------------------
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.deepOrange;

  // --- Translúcidas pré-calculadas (equivalem aos antigos withOpacity) ---
  static const primaryBorderHover = Color(0x59006A60); // primary a 35%
  static const primarySoft =
      Color(0x1F006A60); // primary a 12% (fundo de selos)
  static const neutralSoft =
      Color(0x1F8A94A6); // textSecondary a 12% (fundo de selos)
  static const infoBlueBorder = Color(0x4D2F80ED); // infoBlue a 30%
  static const warningBg = Color(0x14FF5722); // warning a 8%
  static const warningBorder = Color(0x4DFF5722); // warning a 30%
  static const shadowSoft = Color(0x0D000000); // preto a 5%
  static const shadowHover = Color(0x1A000000); // preto a 10%
  static const shadowMap =
      Color(0x1F000000); // preto a 12% (painéis sobre o mapa)
  static const scrim = Color(0xDD000000); // preto a 87% (avisos sobre o mapa)

  // --- Camadas do mapa de pontos (nível de tensão / subestação) ---------
  static const layerHigh = Color(0xFFFF5722);
  static const layerMedium = Color(0xFFFFA000);
  static const layerLow = infoBlue;
  static const layerSubstation = Color(0xFF9C27B0);
}
