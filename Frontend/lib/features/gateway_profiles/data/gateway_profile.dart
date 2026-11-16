/// Perfil técnico de gateway (#TG-78 / #TG-79): os parâmetros de RF que o
/// motor usa no cálculo de cobertura (#TG-150). Espelha o
/// GatewayProfileResponseDto do backend (JSON em camelCase).
class GatewayProfile {
  final int? id;
  final String name;
  final double frequencyMhz;
  final double txPowerDbm;
  final double antennaGainDbi;
  final double rxSensitivityDbm;
  final double antennaHeightM;
  final double sensorHeightM;
  final double extraLossDb;

  /// Exigido pelo backend, mas não usado no cálculo: a tela não mostra e
  /// mantém o valor que já existe (ou [capacidadePadrao] num perfil novo).
  final int maxDevices;

  /// Perfil usado quando o projeto não escolhe um (não pode ser excluído).
  final bool isDefault;

  const GatewayProfile({
    this.id,
    required this.name,
    required this.frequencyMhz,
    required this.txPowerDbm,
    required this.antennaGainDbi,
    required this.rxSensitivityDbm,
    required this.antennaHeightM,
    required this.sensorHeightM,
    required this.extraLossDb,
    this.maxDevices = capacidadePadrao,
    this.isDefault = false,
  });

  static const int capacidadePadrao = 1000;

  /// Valores de referência da Tecsys, usados para preencher um perfil novo.
  static const GatewayProfile referenciaTecsys = GatewayProfile(
    name: '',
    frequencyMhz: 915,
    txPowerDbm: 21,
    antennaGainDbi: 0,
    rxSensitivityDbm: -120,
    antennaHeightM: 6,
    sensorHeightM: 5,
    extraLossDb: 0,
  );

  static double _num(Object? v, double padrao) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? padrao;

  factory GatewayProfile.fromJson(Map<String, dynamic> json) => GatewayProfile(
        id: (json['id'] as num?)?.toInt(),
        name: '${json['name'] ?? ''}',
        frequencyMhz: _num(json['frequencyMhz'], 915),
        txPowerDbm: _num(json['txPowerDbm'], 21),
        antennaGainDbi: _num(json['antennaGainDbi'], 0),
        rxSensitivityDbm: _num(json['rxSensitivityDbm'], -120),
        antennaHeightM: _num(json['antennaHeightM'], 6),
        sensorHeightM: _num(json['sensorHeightM'], 5),
        extraLossDb: _num(json['extraLossDb'], 0),
        maxDevices: (json['maxDevices'] as num?)?.toInt() ?? capacidadePadrao,
        isDefault: json['isDefault'] == true,
      );

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'frequencyMhz': frequencyMhz,
        'txPowerDbm': txPowerDbm,
        'antennaGainDbi': antennaGainDbi,
        'rxSensitivityDbm': rxSensitivityDbm,
        'antennaHeightM': antennaHeightM,
        'sensorHeightM': sensorHeightM,
        'extraLossDb': extraLossDb,
        'maxDevices': maxDevices,
      };

  /// Orçamento de enlace (dB): potência − sensibilidade + ganho − perda.
  double get orcamentoDb =>
      txPowerDbm - rxSensitivityDbm + antennaGainDbi - extraLossDb;

  /// Texto curto para listas e para o seletor do novo projeto.
  String get resumo => '${_fmt(frequencyMhz)} MHz · ${_fmt(txPowerDbm)} dBm · '
      '${_fmt(rxSensitivityDbm)} dBm · perda ${_fmt(extraLossDb)} dB';

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Campos do formulário de perfil, com as faixas aceitas (#TG-79). As
/// faixas cobrem os rádios LoRa/sub-GHz usados pela Tecsys com folga; o
/// backend confere de novo frequência > 0, sensibilidade ≤ 0 e alturas > 0.
enum CampoPerfil {
  nome('Nome', ''),
  frequencia('Frequência', 'MHz', min: 1, max: 6000),
  potencia('Potência de transmissão', 'dBm', min: -10, max: 36),
  ganho('Ganho da antena', 'dBi', min: -10, max: 30),
  sensibilidade('Sensibilidade de recepção', 'dBm', min: -150, max: -40),
  alturaGateway('Altura da antena do gateway', 'm', min: 0.5, max: 200),
  alturaSensor('Altura do sensor', 'm', min: 0.5, max: 200),
  perda('Perda adicional (vegetação, construções)', 'dB', min: 0, max: 60);

  const CampoPerfil(this.rotulo, this.unidade, {this.min, this.max});

  final String rotulo;
  final String unidade;
  final double? min;
  final double? max;

  /// Mensagem de erro do valor digitado, ou null se estiver certo.
  String? validar(String texto) {
    final t = texto.trim();
    if (this == CampoPerfil.nome) {
      if (t.isEmpty) return 'Informe o nome do perfil.';
      if (t.length > 255) return 'Use no máximo 255 caracteres.';
      return null;
    }
    if (t.isEmpty) return 'Informe o valor.';
    final v = double.tryParse(t.replaceAll(',', '.'));
    if (v == null) return 'Use um número (ex.: ${_exemplo()}).';
    if (v < min! || v > max!) {
      return 'Use um valor entre ${_br(min!)} e ${_br(max!)} $unidade.';
    }
    return null;
  }

  static double? lerNumero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  String _exemplo() => switch (this) {
        CampoPerfil.sensibilidade => '-120',
        CampoPerfil.frequencia => '915',
        _ => '6',
      };

  static String _br(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toString().replaceAll('.', ',');
}
