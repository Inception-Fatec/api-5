import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:tecsys_app/core/utils/text_normalizer.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';

class Municipio {
  final int codigoIbge;
  final String nome;
  final String uf;

  const Municipio(
      {required this.codigoIbge, required this.nome, required this.uf});

  String get rotulo => '$nome - $uf';

  @override
  bool operator ==(Object other) =>
      other is Municipio && other.codigoIbge == codigoIbge;
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
  IbgeService({DistribuidorasService? distribuidoras})
      : _distribuidoras = distribuidoras ?? DistribuidorasService();

  final DistribuidorasService _distribuidoras;

  static const _url =
      'https://servicodados.ibge.gov.br/api/v1/localidades/municipios';

  static List<Municipio>? _cache;

  Future<List<Municipio>> _carregarTodos() async {
    if (_cache != null) return _cache!;

    final resposta =
        await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) {
      throw Exception(
          'Não foi possível carregar a lista de municípios do IBGE.');
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
        uf = item['regiao-imediata']?['regiao-intermediaria']?['UF']?['sigla']
                as String? ??
            '';
      } catch (_) {}
      if (uf.isEmpty) {
        try {
          uf = item['microrregiao']?['mesorregiao']?['UF']?['sigla']
                  as String? ??
              '';
        } catch (_) {}
      }
      return Municipio(codigoIbge: id, nome: nome, uf: uf);
    }).toList();

    return _cache!;
  }

  /// Cidades que têm dados da distribuidora [distCode] no banco, com
  /// nome e UF do IBGE, em ordem alfabética. Código que o IBGE não
  /// conhece aparece com o próprio código no lugar do nome.
  Future<List<Municipio>> buscarCidadesComDados(String distCode) async {
    final codigos = await _distribuidoras.codigosMunicipios(distCode);
    if (codigos.isEmpty) return [];
    final porCodigo = {for (final m in await _carregarTodos()) m.codigoIbge: m};
    final cidades = codigos
        .map((c) =>
            porCodigo[c] ?? Municipio(codigoIbge: c, nome: '$c', uf: ''))
        .toList()
      ..sort((a, b) => normalizarTexto(a.nome.toLowerCase())
          .compareTo(normalizarTexto(b.nome.toLowerCase())));
    return cidades;
  }

  /// Carrega a lista do IBGE para [nomeMunicipio] funcionar. Falha em
  /// silêncio: sem a lista, o nome cai para o código.
  Future<void> precarregar() async {
    try {
      await _carregarTodos();
    } catch (_) {}
  }

  /// Nome do município pelo código IBGE (texto), se a lista já foi
  /// carregada; senão devolve o próprio código.
  /// "Vitória - ES" pelo código IBGE, se a lista já foi carregada; senão o
  /// próprio código (#TG-148).
  static String rotuloMunicipio(String codigo) {
    final id = int.tryParse(codigo);
    if (id == null || _cache == null) return codigo;
    for (final m in _cache!) {
      if (m.codigoIbge == id) return m.uf.isEmpty ? m.nome : m.rotulo;
    }
    return codigo;
  }

  /// Cidades separadas por vírgula, em ordem alfabética.
  static String rotulosMunicipios(List<String> codigos) {
    final rotulos = codigos.map(rotuloMunicipio).toList()
      ..sort((a, b) => normalizarTexto(a.toLowerCase()).compareTo(normalizarTexto(b.toLowerCase())));
    return rotulos.join(', ');
  }

  static String nomeMunicipio(String codigo) {
    final id = int.tryParse(codigo);
    if (id == null || _cache == null) return codigo;
    for (final m in _cache!) {
      if (m.codigoIbge == id) return m.nome;
    }
    return codigo;
  }

  Future<List<Municipio>> buscarPorNome(String query) async {
    final todos = await _carregarTodos();
    if (query.trim().isEmpty) return [];
    final termo = normalizarTexto(query.toLowerCase());
    return todos
        .where((m) => normalizarTexto(m.nome.toLowerCase()).contains(termo))
        .take(30)
        .toList();
  }
}
