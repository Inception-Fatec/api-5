import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/core/utils/distributors.dart';

/// Distribuidora que tem dados carregados no banco.
class Distribuidora {
  final String codigo;
  final String nome;

  const Distribuidora({required this.codigo, required this.nome});

  String get rotulo => rotuloDistribuidora(codigo);
}

/// Serviço de acesso a `/distribuidoras`: quais distribuidoras e cidades
/// têm dados no banco (preenchidos pelo ETL).
class DistribuidorasService {
  final ApiClient _client;

  DistribuidorasService({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// GET /distribuidoras — já vem ordenada pela que tem mais
  /// subestações. Registra os nomes para [nomeDistribuidora].
  Future<List<Distribuidora>> listar() async {
    final data = await _client.getJson('/distribuidoras');
    final lista = <Distribuidora>[];
    for (final item in (data as List?) ?? const []) {
      if (item is! Map) continue;
      final codigo = '${item['dist'] ?? ''}'.trim();
      if (codigo.isEmpty) continue;
      lista.add(Distribuidora(codigo: codigo, nome: '${item['nome'] ?? ''}'));
    }
    registrarDistribuidoras({for (final d in lista) d.codigo: d.nome});
    return lista;
  }

  /// GET /distribuidoras/{dist}/municipios — códigos IBGE das cidades
  /// com dados dessa distribuidora.
  Future<List<int>> codigosMunicipios(String distCode) async {
    final data = await _client
        .getJson('/distribuidoras/${Uri.encodeComponent(distCode)}/municipios');
    final codigos = <int>[];
    for (final item in (data as List?) ?? const []) {
      if (item is! Map) continue;
      final codigo = int.tryParse('${item['ibge_code']}');
      if (codigo != null) codigos.add(codigo);
    }
    return codigos;
  }
}
