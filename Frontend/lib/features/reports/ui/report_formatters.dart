/// Formatação pt-BR dos números do relatório (o app não usa `intl`).

/// 1234567 -> "1.234.567".
String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// 98.0 -> "98,00%"; 53.333 -> "53,33%".
String formatPercent(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')}%';

/// 4000 -> "4 km"; 2500 -> "2,5 km"; 800 -> "800 m".
String formatRange(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  final text = km == km.roundToDouble()
      ? km.round().toString()
      : km.toStringAsFixed(1).replaceAll('.', ',');
  return '$text km';
}

/// 100.0 -> "100%"; 53.33 -> "53,3%" (curto, para caber no anel).
String formatPercentCompact(double value) => value == value.roundToDouble()
    ? '${value.round()}%'
    : '${value.toStringAsFixed(1).replaceAll('.', ',')}%';

/// Decimal com [digits] casas e vírgula (pt-BR): 12.345 -> "12,3".
String formatDecimal(double value, {int digits = 1}) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

/// Coordenada em graus decimais com ponto e 6 casas (cola direto no
/// Google Maps): -23.1896, -45.8841 -> "-23.189600, -45.884100".
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
