import 'package:tecsys_app/core/network/api_client.dart';
import 'package:tecsys_app/core/utils/distributors.dart';

/// Distribuidora que tem dados no banco (rede da BDGD ou pontos de CSV).
class Distribuidora {
  final String codigo;
  final String nome;

  /// Tem rede da BDGD carregada. Falso = só pontos de CSV ou recém-cadastrada:
  /// rede independente (#TG-151).
  final bool temRede;

  const Distribuidora({required this.codigo, required this.nome, this.temRede = true});

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
  ///
  /// [incluirCadastradas] traz também as distribuidoras cadastradas ainda sem
  /// dados (modal de importação de CSV, #TG-151).
  Future<List<Distribuidora>> listar({bool incluirCadastradas = false}) async {
    final data = await _client.getJson(
        incluirCadastradas ? '/distribuidoras?incluirCadastradas=true' : '/distribuidoras');
    final lista = <Distribuidora>[];
    for (final item in (data as List?) ?? const []) {
      if (item is! Map) continue;
      final codigo = '${item['dist'] ?? ''}'.trim();
      if (codigo.isEmpty) continue;
      final totalSub = num.tryParse('${item['total_sub'] ?? ''}');
      lista.add(Distribuidora(
        codigo: codigo,
        nome: '${item['nome'] ?? ''}',
        temRede: totalSub == null || totalSub > 0,
      ));
    }
    registrarDistribuidoras({for (final d in lista) d.codigo: d.nome});
    return lista;
  }

  /// GET /distribuidoras/{dist}/municipios — códigos IBGE das cidades
  /// com dados dessa distribuidora.
  Future<List<int>> codigosMunicipios(String distCode) async =>
      [for (final m in await municipios(distCode)) m.codigo];

  /// Cidades com dados da distribuidora e a origem deles: rede da BDGD e/ou
  /// pontos importados por CSV (#TG-151).
  Future<List<MunicipioComDados>> municipios(String distCode) async {
    final data = await _client
        .getJson('/distribuidoras/${Uri.encodeComponent(distCode)}/municipios');
    final lista = <MunicipioComDados>[];
    for (final item in (data as List?) ?? const []) {
      if (item is! Map) continue;
      final codigo = int.tryParse('${item['ibge_code']}');
      if (codigo == null) continue;
      lista.add(MunicipioComDados(
        codigo: codigo,
        // resposta antiga (sem os campos) = cidade com rede da BDGD
        temRede: item['tem_rede'] != false,
        temCsv: item['tem_csv'] == true,
      ));
    }
    return lista;
  }

  /// POST /distribuidoras — cadastra uma distribuidora sem BDGD (#TG-151).
  /// Código repetido volta como erro com a mensagem do servidor.
  Future<Distribuidora> cadastrar({required String codigo, required String nome}) async {
    final data = await _client.postJson('/distribuidoras', {'codigo': codigo, 'nome': nome});
    final d = Distribuidora(
      codigo: '${data['dist'] ?? codigo}',
      nome: '${data['nome'] ?? nome}',
      temRede: false,
    );
    registrarDistribuidoras({d.codigo: d.nome});
    return d;
  }
}

/// Cidade com dados de uma distribuidora e de onde eles vêm (#TG-151).
class MunicipioComDados {
  final int codigo;
  final bool temRede;
  final bool temCsv;

  const MunicipioComDados({required this.codigo, required this.temRede, required this.temCsv});
}
