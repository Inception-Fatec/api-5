import 'dart:convert';
import 'dart:typed_data';

/// Prévia do CSV de pontos externos (#TG-90), lida no próprio navegador
/// antes do envio.
///
/// Espelha as regras de leitura do backend (`ExternalPointsImportService`,
/// #TG-89) só no que dá para avisar cedo: separador `;`, aspas com `""`,
/// cabeçalho em qualquer ordem e sem diferenciar maiúsculas, BOM tolerado.
/// A validação oficial, linha a linha, continua sendo a do backend — aqui
/// não se confere coordenada nem papel.

/// Separador fixo do arquivo (o mesmo do backend).
const String kSeparadorCsv = ';';

/// Colunas que o backend exige no cabeçalho; `descricao` é opcional.
const List<String> kColunasObrigatoriasCsv = <String>[
  'id',
  'latitude',
  'longitude',
  'papel',
];

/// Valores aceitos na coluna `papel`.
const List<String> kPapeisCsv = <String>[
  'candidato',
  'ponto_a_cobrir',
  'interesse',
];

/// Nome do arquivo de modelo oferecido para download.
const String kNomeModeloCsv = 'modelo_pontos.csv';

/// Conteúdo do modelo: uma linha de exemplo por papel (coordenadas em São
/// José dos Campos). Decimal com vírgula porque o público usa o Excel em
/// português, que trata "-23.17" como texto/data e estraga o número ao
/// salvar de novo; o backend aceita ponto ou vírgula.
const String kModeloCsv = 'id;latitude;longitude;papel;descricao\r\n'
    'CAND-001;-23,1791;-45,8872;candidato;Topo do prédio da subestação\r\n'
    'COB-001;-23,2237;-45,9009;ponto_a_cobrir;Medidor de cliente rural\r\n'
    'INT-001;-23,1896;-45,8841;interesse;Escola municipal\r\n';

/// Bytes do modelo em UTF-8 com BOM: sem o BOM o Excel abre os acentos
/// errados; o backend ignora o BOM no cabeçalho.
Uint8List bytesModeloCsv() => bytesCsvComBom(kModeloCsv);

/// [texto] em UTF-8 com BOM, para o Excel reconhecer a codificação.
Uint8List bytesCsvComBom(String texto) =>
    Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(texto)]);

/// Decodifica como o backend: UTF-8 e, se não for UTF-8 válido (CSV salvo
/// pelo Excel em português), Latin-1 — igual ao Windows-1252 nos acentos
/// do português, que é o que importa para a prévia.
String decodificarCsv(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Confere o arquivo antes da prévia: extensão `.csv` (o backend valida
/// pelo nome) e conteúdo não vazio. Devolve a mensagem de erro ou `null`.
String? validarArquivoCsv(String nome, Uint8List bytes) {
  if (!nome.toLowerCase().endsWith('.csv')) {
    return 'O arquivo "$nome" não é um CSV. Envie um arquivo com extensão .csv '
        'e colunas separadas por ponto e vírgula (;). Se precisar, baixe o modelo acima.';
  }
  if (bytes.isEmpty || analisarCsv(decodificarCsv(bytes)).vazio) {
    return 'O arquivo "$nome" está vazio.';
  }
  return null;
}

/// Divide uma linha por `;` respeitando aspas (`""` vira `"`), como o
/// `dividirLinha` do backend. As células não são aparadas aqui.
List<String> dividirLinhaCsv(String linha) {
  final List<String> campos = <String>[];
  final StringBuffer atual = StringBuffer();
  bool entreAspas = false;
  for (int i = 0; i < linha.length; i++) {
    final String ch = linha[i];
    if (ch == '"') {
      if (entreAspas && i + 1 < linha.length && linha[i + 1] == '"') {
        atual.write('"');
        i++;
      } else {
        entreAspas = !entreAspas;
      }
    } else if (ch == kSeparadorCsv && !entreAspas) {
      campos.add(atual.toString());
      atual.clear();
    } else {
      atual.write(ch);
    }
  }
  campos.add(atual.toString());
  return campos;
}

/// Uma linha de dados da prévia. [numero] conta o cabeçalho como linha 1,
/// igual à `linha` das rejeições do backend, para o ADM poder comparar.
class LinhaPreviaCsv {
  const LinhaPreviaCsv(this.numero, this.celulas);

  final int numero;
  final List<String> celulas;
}

/// Resultado de [analisarCsv].
class PreviaCsv {
  const PreviaCsv({
    required this.cabecalho,
    required this.linhas,
    required this.totalLinhas,
    required this.colunasFaltando,
    required this.pareceSeparadorVirgula,
  });

  /// Nomes das colunas como estão no arquivo (aparados, sem o BOM).
  final List<String> cabecalho;

  /// Primeiras linhas de dados não vazias.
  final List<LinhaPreviaCsv> linhas;

  /// Total de linhas de dados não vazias (o `total` que o backend conta).
  final int totalLinhas;

  /// Colunas obrigatórias que não estão no cabeçalho.
  final List<String> colunasFaltando;

  /// Cabeçalho com uma coluna só, contendo vírgulas: provavelmente o
  /// arquivo foi salvo com `,` como separador.
  final bool pareceSeparadorVirgula;

  /// Sem cabeçalho (arquivo vazio ou só com espaços/linhas em branco).
  bool get vazio => cabecalho.isEmpty;

  /// Linhas cujo número de colunas difere do cabeçalho (entre as da prévia).
  bool linhaDesalinhada(LinhaPreviaCsv l) => l.celulas.length != cabecalho.length;

  /// Se vale a pena enviar: o backend recusaria o arquivo inteiro (422)
  /// sem cabeçalho completo ou sem linhas de dados.
  bool get podeEnviar =>
      !vazio && colunasFaltando.isEmpty && totalLinhas > 0;

  /// Problemas que impedem o envio, em texto para o ADM.
  List<String> get avisos {
    if (vazio) return const <String>['O arquivo está vazio.'];
    return <String>[
      if (pareceSeparadorVirgula)
        'O arquivo parece usar vírgula (,) como separador. Salve-o com '
            'ponto e vírgula (;) separando as colunas.',
      if (colunasFaltando.isNotEmpty)
        'Faltam ${colunasFaltando.length == 1 ? 'a coluna obrigatória' : 'as colunas obrigatórias'} '
            '${colunasFaltando.join(', ')} no cabeçalho (1ª linha).',
      if (totalLinhas == 0)
        'O arquivo só tem o cabeçalho: não há linhas de dados.',
    ];
  }
}

/// Lê o cabeçalho e as primeiras [maxLinhas] linhas de dados de [texto].
///
/// Linhas em branco são ignoradas (como no backend). O cabeçalho é a
/// primeira linha do arquivo: se ela estiver em branco, o backend responde
/// "O CSV está vazio.", e aqui o resultado também é [PreviaCsv.vazio].
PreviaCsv analisarCsv(String texto, {int maxLinhas = 5}) {
  // \r\n, \n ou \r, como o BufferedReader.readLine do backend.
  final List<String> brutas = texto.split(RegExp(r'\r\n|\n|\r'));
  // Um "\n" no fim do arquivo não é uma linha a mais.
  if (brutas.isNotEmpty && brutas.last.isEmpty) brutas.removeLast();

  String primeira = brutas.isEmpty ? '' : brutas.first;
  if (primeira.startsWith('﻿')) primeira = primeira.substring(1);
  if (primeira.trim().isEmpty) {
    return const PreviaCsv(
      cabecalho: <String>[],
      linhas: <LinhaPreviaCsv>[],
      totalLinhas: 0,
      colunasFaltando: kColunasObrigatoriasCsv,
      pareceSeparadorVirgula: false,
    );
  }

  final List<String> cabecalho =
      dividirLinhaCsv(primeira).map((c) => c.trim()).toList();
  final Set<String> nomes = cabecalho.map((c) => c.toLowerCase()).toSet();
  final List<String> faltando =
      kColunasObrigatoriasCsv.where((c) => !nomes.contains(c)).toList();

  final List<LinhaPreviaCsv> linhas = <LinhaPreviaCsv>[];
  int total = 0;
  for (int i = 1; i < brutas.length; i++) {
    final String linha = brutas[i];
    if (linha.trim().isEmpty) continue;
    total++;
    if (linhas.length < maxLinhas) {
      linhas.add(LinhaPreviaCsv(
          i + 1, dividirLinhaCsv(linha).map((c) => c.trim()).toList()));
    }
  }

  return PreviaCsv(
    cabecalho: cabecalho,
    linhas: linhas,
    totalLinhas: total,
    colunasFaltando: faltando,
    pareceSeparadorVirgula: cabecalho.length == 1 && cabecalho.first.contains(','),
  );
}

/// Célula de CSV com `;`: entre aspas (e `"` dobrada) quando o texto tem
/// `;`, aspas ou quebra de linha, como o backend espera ao ler.
String celulaCsv(String s) =>
    RegExp(r'[;"\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
