import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/projects/ui/comparacao_textos.dart';

/// Selo do Δ em relação à referência: verde quando o cenário é melhor,
/// vermelho quando é pior, cinza quando é igual.
class ChipDelta extends StatelessWidget {
  const ChipDelta._({super.key, required this.texto, required this.sinal});

  /// Mais cobertura é melhor.
  factory ChipDelta.cobertura(double pp, {Key? key}) {
    final texto = formatarDeltaCobertura(pp);
    return ChipDelta._(
        key: key, texto: texto, sinal: texto.startsWith('0') ? 0 : pp.sign.toInt());
  }

  /// Menos gateways é melhor.
  factory ChipDelta.gateways(int d, {Key? key}) =>
      ChipDelta._(key: key, texto: formatarDeltaGateways(d), sinal: -d.sign);

  /// Mais consumidores atendidos é melhor.
  factory ChipDelta.atendidos(int d, {Key? key}) =>
      ChipDelta._(key: key, texto: formatarDeltaGateways(d), sinal: d.sign);

  /// Mais consumidores por gateway é melhor.
  factory ChipDelta.porGateway(double d, {Key? key}) {
    final texto = formatarDeltaDecimal(d);
    return ChipDelta._(
        key: key, texto: texto, sinal: texto.startsWith('0') ? 0 : d.sign.toInt());
  }

  final String texto;

  /// 1 = melhor que a referência, -1 = pior, 0 = igual.
  final int sinal;

  @override
  Widget build(BuildContext context) {
    final cor = switch (sinal) {
      > 0 => AppColors.success,
      < 0 => AppColors.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: AppRadius.pill,
      ),
      child: Text('Δ $texto',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cor)),
    );
  }
}
