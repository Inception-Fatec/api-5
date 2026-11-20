import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';

/// Letra do cenário na ordem em que foi marcado (A = referência).
String letraCenario(int i) => String.fromCharCode(65 + i % 26);

/// "A", "A e B", "A, B e C".
String juntarLetras(List<String> letras) => letras.length < 2
    ? letras.join()
    : '${letras.sublist(0, letras.length - 1).join(', ')} e ${letras.last}';

/// Δ de cobertura em pontos percentuais: "+5,00 p.p.", "−1,25 p.p.".
String formatarDeltaCobertura(double pp) {
  final arredondado = double.parse(pp.toStringAsFixed(2));
  if (arredondado == 0) return '0,00 p.p.';
  return '${arredondado > 0 ? '+' : '−'}'
      '${formatDecimal(arredondado.abs(), digits: 2)} p.p.';
}

/// Δ inteiro: "+2", "−1.406", "0".
String formatarDeltaGateways(int d) =>
    d == 0 ? '0' : '${d > 0 ? '+' : '−'}${formatInt(d.abs())}';

/// Δ com uma casa: "+754,5", "−3,0", "0,0".
String formatarDeltaDecimal(double d) {
  final arredondado = double.parse(d.toStringAsFixed(1));
  if (arredondado == 0) return '0,0';
  return '${arredondado > 0 ? '+' : '−'}${formatDecimal(arredondado.abs())}';
}

/// Leitura em uma frase: "B tem a mesma cobertura que A, com 2 gateways a
/// menos." / "C cobre 5,00 p.p. a mais que A, com 1 gateway a mais."
String leituraCenario(String letra, DeltaCenario d) {
  final pp = double.parse(d.coberturaPp.toStringAsFixed(2));
  final cobertura = pp == 0
      ? 'tem a mesma cobertura que A'
      : 'cobre ${formatDecimal(pp.abs(), digits: 2)} p.p. a '
          '${pp > 0 ? 'mais' : 'menos'} que A';
  final n = d.gateways.abs();
  final gateways = d.gateways == 0
      ? 'com o mesmo número de gateways'
      : 'com $n gateway${n == 1 ? '' : 's'} a ${d.gateways < 0 ? 'menos' : 'mais'}';
  return '$letra $cobertura, $gateways.';
}
