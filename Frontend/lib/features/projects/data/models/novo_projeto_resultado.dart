import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Dados básicos escolhidos no popup "Novo Projeto", que seguem para o
/// mapa de pontos.
class NovoProjetoResultado {
  final String nome;
  final String distCode;
  final String distribuidoraLabel;
  final List<Municipio> municipios;

  const NovoProjetoResultado({
    required this.nome,
    required this.distCode,
    required this.distribuidoraLabel,
    required this.municipios,
  });
}
