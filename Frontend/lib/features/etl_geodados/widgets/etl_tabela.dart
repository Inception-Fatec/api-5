import 'package:flutter/material.dart';

import '../etl_theme.dart';

/// Tabela compacta dos modais do ETL (#TG-90): prévia do CSV antes de
/// importar e pontos gravados por uma importação. Rola na horizontal (e na
/// vertical, com [alturaMaxima]); a primeira coluna é a numeração, em cinza.
class EtlTabela extends StatelessWidget {
  const EtlTabela({
    super.key,
    required this.cabecalho,
    required this.linhas,
    this.colunasDestacadas = const <String>{},
    this.linhasEmAlerta = const <int>{},
    this.alturaMaxima,
  });

  /// Títulos das colunas; o primeiro é o da numeração (ex.: "#").
  final List<String> cabecalho;

  /// Células de cada linha, na mesma ordem do [cabecalho]. Linhas mais
  /// curtas são completadas com vazio.
  final List<List<String>> linhas;

  /// Títulos (em minúsculas) destacados no cabeçalho, ex.: colunas obrigatórias.
  final Set<String> colunasDestacadas;

  /// Índices de [linhas] com fundo âmbar (ex.: colunas a mais ou a menos).
  final Set<int> linhasEmAlerta;

  final double? alturaMaxima;

  @override
  Widget build(BuildContext context) {
    final int colunas = [
      cabecalho.length,
      for (final List<String> l in linhas) l.length,
    ].reduce((a, b) => a > b ? a : b);

    TableRow linha(List<String> celulas, {required bool titulo, bool alerta = false}) {
      return TableRow(
        decoration: BoxDecoration(
          color: titulo ? EtlColors.slate100 : (alerta ? EtlColors.amber50 : Colors.white),
        ),
        children: [
          for (int i = 0; i < colunas; i++)
            _celula(
              i < celulas.length ? celulas[i] : '',
              titulo: titulo,
              numeracao: i == 0,
              destaque: titulo && i < celulas.length && colunasDestacadas.contains(celulas[i].toLowerCase()),
            ),
        ],
      );
    }

    final Widget tabela = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: const TableBorder(
          horizontalInside: BorderSide(color: EtlColors.slate100),
          verticalInside: BorderSide(color: EtlColors.slate100),
        ),
        children: [
          linha(cabecalho, titulo: true),
          for (int i = 0; i < linhas.length; i++)
            linha(linhas[i], titulo: false, alerta: linhasEmAlerta.contains(i)),
        ],
      ),
    );

    final double? altura = alturaMaxima;
    return Container(
      constraints: altura == null ? null : BoxConstraints(maxHeight: altura),
      decoration: BoxDecoration(
        border: Border.all(color: EtlColors.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: altura == null ? tabela : Scrollbar(child: SingleChildScrollView(primary: false, child: tabela)),
      ),
    );
  }

  static Widget _celula(String texto,
      {required bool titulo, required bool numeracao, required bool destaque}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: etlText(
            12,
            weight: titulo ? FontWeight.w600 : FontWeight.w400,
            color: numeracao
                ? EtlColors.slate400
                : (destaque ? EtlColors.teal800 : (titulo ? EtlColors.slate700 : EtlColors.slate800)),
            lineHeight: 16,
            mono: !numeracao,
          ),
        ),
      ),
    );
  }
}
