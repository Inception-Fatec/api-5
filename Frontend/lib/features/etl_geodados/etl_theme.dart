import 'package:flutter/material.dart';

/// Paleta extraída do protótipo Stitch (Tailwind slate / teal / emerald / rose).
class EtlColors {
  EtlColors._();

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal800 = Color(0xFF115E59);

  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);

  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose900 = Color(0xFF881337);

  // Variantes com transparência (equivalentes a bg-teal-50/60, etc.).
  static const Color overlay = Color(0x990F172A); // slate-900/60
  static const Color teal50a30 = Color(0x4DF0FDFA);
  static const Color teal50a20 = Color(0x33F0FDFA);
  static const Color teal50a60 = Color(0x99F0FDFA);
  static const Color teal50Clear = Color(0x00F0FDFA);
  static const Color teal500Clear = Color(0x0014B8A6);
  static const Color slate50a50 = Color(0x80F8FAFC);
  static const Color slate50a60 = Color(0x99F8FAFC);
  static const Color slate200a80 = Color(0xCCE2E8F0);
  static const Color rose50a70 = Color(0xB3FFF1F2);
  static const Color black5 = Color(0x0D000000);
  static const Color black10 = Color(0x1A000000);
  static const Color black25 = Color(0x40000000);
  static const Color teal700Shadow10 = Color(0x1A0F766E);
  static const Color teal600Shadow20 = Color(0x330D9488);
}

/// Raio do card do modal. O pedido define 16; o HTML do Stitch usa rounded-3xl (24).
const double kEtlModalRadius = 16;

/// Estilo de texto equivalente às classes Tailwind do protótipo.
/// [lineHeight] em pixels (ex.: text-sm = 20, text-xs = 16).
TextStyle etlText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = EtlColors.slate800,
  double? lineHeight,
  double letterSpacing = 0,
  bool mono = false,
}) {
  return TextStyle(
    fontFamily: mono ? 'DejaVu Sans Mono' : 'Inter',
    fontFamilyFallback: mono
        ? const ['Liberation Mono', 'Ubuntu Mono', 'monospace']
        : const ['Ubuntu', 'Noto Sans', 'DejaVu Sans'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: lineHeight == null ? null : lineHeight / size,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: letterSpacing,
    decoration: TextDecoration.none,
  );
}
