import 'dart:convert';
import 'package:http/http.dart' as http;

class Municipio {
  final int codigoIbge;
  final String nome;
  final String uf;

  const Municipio({required this.codigoIbge, required this.nome, required this.uf});

  String get rotulo => '$nome - $uf';

  @override
  bool operator ==(Object other) => other is Municipio && other.codigoIbge == codigoIbge;
  @override
  int get hashCode => codigoIbge.hashCode;
}

/// Busca de municípios brasileiros via API pública do IBGE
/// (servicodados.ibge.gov.br) — sem necessidade de chave.
///
/// A API não tem um endpoint de "busca por nome" — ela retorna a lista
/// completa (~5.570 municípios). Por isso buscamos e guardamos em
/// cache uma vez só, e filtramos localmente a cada busca — rápido e
/// evita bater na API repetidamente.
class IbgeService {
  static const _url = 'https://servicodados.ibge.gov.br/api/v1/localidades/municipios';

  static List<Municipio>? _cache;

  Future<List<Municipio>> _carregarTodos() async {
    if (_cache != null) return _cache!;

    final resposta = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar a lista de municípios do IBGE.');
    }

    final lista = jsonDecode(resposta.body) as List;
    _cache = lista.map((item) {
      final id = item['id'] as int;
      final nome = item['nome'] as String;
      // Estrutura aninhada da API do IBGE — o caminho até a UF mudou
      // de versão pra versão, então tentamos os dois formatos
      // conhecidos antes de desistir e deixar em branco.
      String uf = '';
      try {
        uf = item['regiao-imediata']?['regiao-intermediaria']?['UF']?['sigla'] as String? ?? '';
      } catch (_) {}
      if (uf.isEmpty) {
        try {
          uf = item['microrregiao']?['mesorregiao']?['UF']?['sigla'] as String? ?? '';
        } catch (_) {}
      }
      return Municipio(codigoIbge: id, nome: nome, uf: uf);
    }).toList();

    return _cache!;
  }

  Future<List<Municipio>> buscarPorNome(String query) async {
    final todos = await _carregarTodos();
    if (query.trim().isEmpty) return [];
    final termo = query.toLowerCase();
    return todos
        .where((m) => m.nome.toLowerCase().contains(termo))
        .take(30)
        .toList();
  }
}