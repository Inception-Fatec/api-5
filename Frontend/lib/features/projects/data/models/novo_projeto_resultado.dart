import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Dados básicos escolhidos no popup "Novo Projeto", que seguem para o
/// mapa de pontos.
class NovoProjetoResultado {
  final String nome;
  final String distCode;
  final String distribuidoraLabel;
  final List<Municipio> municipios;

  /// Perfil de gateway escolhido (#TG-79); null = o backend usa o padrão.
  final int? gatewayProfileId;

  const NovoProjetoResultado({
    required this.nome,
    required this.distCode,
    required this.distribuidoraLabel,
    required this.municipios,
    this.gatewayProfileId,
  });
}
