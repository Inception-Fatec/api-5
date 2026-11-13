import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../etl_theme.dart';
import '../models/csv_import_resumo.dart';
import '../services/csv_preview.dart';
import '../services/salvar_arquivo.dart';
import 'etl_modal.dart';

/// Resumo de uma importação de CSV (#TG-90): números, avisos e as linhas
/// rejeitadas com o motivo. Usado no fim da importação (modal de envio) e
/// nos detalhes do item de CSV no histórico de cargas.
class CsvResumoImportacao extends StatefulWidget {
  const CsvResumoImportacao({
    super.key,
    required this.resumo,
    required this.nomeArquivo,
    this.mostrarNumeros = true,
  });

  final CsvImportResumo resumo;

  /// Nome do .csv (para o arquivo das rejeitadas: "<nome>_rejeitadas.csv").
  final String nomeArquivo;

  /// Os detalhes do histórico já mostram os números nas métricas do topo.
  final bool mostrarNumeros;

  @override
  State<CsvResumoImportacao> createState() => _CsvResumoImportacaoState();
}

class _CsvResumoImportacaoState extends State<CsvResumoImportacao> {
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.resumo.rejeicoesCsv()));
    if (mounted) setState(() => _copiado = true);
  }

  Future<void> _baixar() async {
    final String base =
        widget.nomeArquivo.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
    try {
      await salvarArquivo(
          nome: '${base}_rejeitadas.csv', bytes: bytesCsvComBom(widget.resumo.rejeicoesCsv()));
    } catch (_) {
      // Download é um extra; "Copiar" continua disponível.
    }
  }

  @override
  Widget build(BuildContext context) {
    final CsvImportResumo r = widget.resumo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mostrarNumeros) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Numero(
                  valor: r.importadas,
                  rotulo: r.importadas == 1 ? 'importada' : 'importadas',
                  cor: EtlColors.emerald700,
                  fundo: EtlColors.emerald50,
                  borda: EtlColors.emerald200),
              _Numero(
                  valor: r.jaExistentes,
                  rotulo: r.jaExistentes == 1 ? 'já existente' : 'já existentes',
                  cor: EtlColors.slate700,
                  fundo: EtlColors.slate50,
                  borda: EtlColors.slate200),
              _Numero(
                  valor: r.rejeitadas,
                  rotulo: r.rejeitadas == 1 ? 'rejeitada' : 'rejeitadas',
                  cor: r.rejeitadas > 0 ? EtlColors.rose700 : EtlColors.slate700,
                  fundo: r.rejeitadas > 0 ? EtlColors.rose50a70 : EtlColors.slate50,
                  borda: r.rejeitadas > 0 ? EtlColors.rose200 : EtlColors.slate200),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(r.texto,
            style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16)),
        if (r.soJaExistentes) ...[
          const SizedBox(height: 12),
          EtlAvisoLinha(
            mensagem: 'Nenhum ponto novo: ${r.jaExistentes == 1 ? 'o ponto válido já tinha' : 'os ${r.jaExistentes} pontos válidos já tinham'} '
                'sido importado${r.jaExistentes == 1 ? '' : 's'} para essa distribuidora. '
                'O id é único por distribuidora e pontos já existentes não são alterados.',
          ),
        ] else if (r.jaExistentes > 0) ...[
          const SizedBox(height: 12),
          EtlAvisoLinha(
            mensagem: '${r.jaExistentes} ${r.jaExistentes == 1 ? 'linha tinha um id que já existia' : 'linhas tinham ids que já existiam'} '
                'nessa distribuidora e ${r.jaExistentes == 1 ? 'foi ignorada' : 'foram ignoradas'} (o ponto gravado antes não muda).',
          ),
        ] else if (r.importadas > 0 && r.rejeitadas == 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: EtlColors.emerald700),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Todas as linhas foram importadas.',
                    style: etlText(12, color: EtlColors.emerald800, lineHeight: 16)),
              ),
            ],
          ),
        ],
        if (r.rejeicoes.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ListaRejeicoes(
            rejeicoes: r.rejeicoes,
            omitidas: r.rejeicoesOmitidas,
            copiado: _copiado,
            onCopiar: _copiar,
            onBaixar: _baixar,
          ),
        ],
      ],
    );
  }
}

/// Aviso de uma linha: âmbar (atenção) ou rosa ([erro]).
class EtlAvisoLinha extends StatelessWidget {
  const EtlAvisoLinha({super.key, required this.mensagem, this.erro = false, this.acao});

  final String mensagem;
  final bool erro;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: erro ? EtlColors.rose50a70 : EtlColors.amber50,
        border: Border.all(color: erro ? EtlColors.rose200 : EtlColors.amber200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(erro ? Icons.error_outline : Icons.warning_amber_rounded,
                size: 16, color: erro ? EtlColors.rose600 : EtlColors.amber600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensagem,
                style: etlText(12,
                    color: erro ? EtlColors.rose700 : EtlColors.amber800, lineHeight: 18)),
          ),
          if (acao != null) acao!,
        ],
      ),
    );
  }
}

/// Número grande do resumo ("8 importadas").
class _Numero extends StatelessWidget {
  const _Numero({
    required this.valor,
    required this.rotulo,
    required this.cor,
    required this.fundo,
    required this.borda,
  });

  final int valor;
  final String rotulo;
  final Color cor;
  final Color fundo;
  final Color borda;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fundo,
        border: Border.all(color: borda),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$valor', style: etlText(24, weight: FontWeight.w700, color: cor, lineHeight: 32)),
          Text(rotulo, style: etlText(12, weight: FontWeight.w500, color: cor, lineHeight: 16)),
        ],
      ),
    );
  }
}

/// Lista rolável das linhas rejeitadas: linha, id e motivo.
class _ListaRejeicoes extends StatelessWidget {
  const _ListaRejeicoes({
    required this.rejeicoes,
    required this.omitidas,
    required this.copiado,
    required this.onCopiar,
    required this.onBaixar,
  });

  final List<CsvRejeicao> rejeicoes;
  final int omitidas;
  final bool copiado;
  final VoidCallback onCopiar;
  final VoidCallback onBaixar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text('Linhas rejeitadas (${rejeicoes.length + omitidas})',
                style: etlText(13, weight: FontWeight.w700, color: EtlColors.slate900, lineHeight: 20)),
            Wrap(
              spacing: 4,
              children: [
                EtlBotaoLink(
                  icone: copiado ? Icons.check : Icons.copy_outlined,
                  label: copiado ? 'Copiado' : 'Copiar',
                  onTap: onCopiar,
                ),
                EtlBotaoLink(
                    icone: Icons.download_outlined, label: 'Baixar .csv', onTap: onBaixar),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: EtlColors.rose200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                primary: false,
                itemCount: rejeicoes.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: EtlColors.rose200),
                itemBuilder: (context, i) {
                  final CsvRejeicao r = rejeicoes[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text('Linha ${r.linha}',
                              style: etlText(12,
                                  weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 18)),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: r.id.isEmpty ? '(sem id)' : r.id,
                                style: etlText(12,
                                    weight: FontWeight.w600,
                                    color: EtlColors.slate900,
                                    lineHeight: 18,
                                    mono: r.id.isNotEmpty),
                              ),
                              TextSpan(
                                text: ' — ${r.motivo}',
                                style: etlText(12, color: EtlColors.rose700, lineHeight: 18),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (omitidas > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Mais $omitidas ${omitidas == 1 ? 'linha rejeitada não foi guardada' : 'linhas rejeitadas não foram guardadas'} '
            'no histórico (ele guarda as primeiras 500).',
            style: etlText(11, color: EtlColors.slate500, lineHeight: 16),
          ),
        ],
      ],
    );
  }
}
