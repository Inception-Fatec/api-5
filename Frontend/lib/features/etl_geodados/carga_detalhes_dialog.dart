import 'package:flutter/material.dart';

import 'etl_theme.dart';
import 'models/csv_import_resumo.dart';
import 'models/etl_carga.dart';
import 'models/ponto_importado.dart';
import 'services/etl_service.dart';
import 'services/salvar_arquivo.dart';
import 'services/csv_preview.dart';
import 'widgets/csv_resumo.dart';
import 'widgets/seletor_municipio.dart';
import 'widgets/etl_buttons.dart';
import 'widgets/etl_modal.dart';
import 'widgets/etl_tabela.dart';
import 'package:tecsys_app/core/widgets/app_filter_chip.dart';

/// Busca os pontos gravados por uma importação de CSV. Trocável nos testes.
typedef CarregarPontosDaImportacao = Future<PontosDaImportacao> Function(String cargaId);

/// Modal "Detalhes da carga" (aberto ao clicar num card da lista). Para uma
/// importação de CSV (#TG-90) mostra o resumo, as rejeitadas e as linhas
/// gravadas; para o .zip, as métricas e as camadas carregadas.
class CargaDetalhesDialog extends StatelessWidget {
  const CargaDetalhesDialog({super.key, required this.carga, this.carregarPontos});

  final EtlCarga carga;
  final CarregarPontosDaImportacao? carregarPontos;

  static Future<bool?> show(BuildContext context, EtlCarga carga) =>
      mostrarModalEtl<bool>(context, CargaDetalhesDialog(carga: carga), fecharAoClicarFora: true);

  @override
  Widget build(BuildContext context) {
    final EtlCarga c = carga;
    void fechar() => Navigator.of(context).pop();

    return EtlModalCard(
      onEsc: fechar,
      larguraMaxima: 672,
      cabecalho: _Cabecalho(carga: c, onFechar: fechar),
      conteudo: c.ehCsv ? _detalhesCsv(c) : _detalhesEtl(c),
      rodape: [EtlOutlineButton(label: 'Fechar', onPressed: fechar)],
    );
  }

  /// Linha de métricas do topo: tamanho e tempo (iguais para .zip e CSV) e
  /// duas métricas próprias de cada tipo.
  Widget _metricas(EtlCarga c, _Metrica terceira, _Metrica quarta) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Metrica(rotulo: 'Tamanho do Arquivo', valor: c.tamanhoBytes > 0 ? c.tamanhoFormatado : '—')),
          const SizedBox(width: 12),
          Expanded(
            child: _Metrica(
              rotulo: 'Tempo de Processamento',
              valor: c.duracao ?? '—',
              corValor: EtlColors.teal700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: terceira),
          const SizedBox(width: 12),
          Expanded(child: quarta),
        ],
      ),
    );
  }

  List<Widget> _detalhesEtl(EtlCarga c) {
    return [
      _metricas(
        c,
        _Metrica(rotulo: 'Tabelas Carregadas', valor: c.totalCamadas > 0 ? '${c.totalCamadas}' : '—'),
        _Metrica(
          rotulo: 'Registros Gravados',
          valor: c.camadas.isEmpty ? '—' : EtlCarga.milhar(c.totalGravados),
          corValor: EtlColors.slate900,
        ),
      ),
      if (c.status == EtlCargaStatus.erro) ...[
        const SizedBox(height: 16),
        _Falha(mensagem: c.errorMessage, log: c.logTail),
      ],
      for (final aviso in c.avisos) ...[
        const SizedBox(height: 16),
        EtlAvisoLinha(mensagem: aviso),
      ],
      const SizedBox(height: 20),
      _SecaoCamadas(camadas: c.camadas),
      for (final bt in c.camadas.where((k) => k.nome == 'ucbt' && k.consumidores > 0)) ...[
        const SizedBox(height: 12),
        Text(
          'Baixa tensão: ${EtlCarga.milhar(bt.consumidores)} consumidores '
          '(inclusive residenciais) gravados em ${EtlCarga.milhar(bt.gravados)} registros, '
          'um por ponto de conexão e classe.',
          style: etlText(12, color: EtlColors.slate500, lineHeight: 18),
        ),
      ],
    ];
  }

  /// Importação de CSV (#TG-90): as mesmas métricas do topo, com os números
  /// da importação, e o resumo com as linhas rejeitadas e o motivo.
  List<Widget> _detalhesCsv(EtlCarga c) {
    final CsvImportResumo? r = c.csv;
    return [
      _metricas(
        c,
        _Metrica(rotulo: 'Linhas no Arquivo', valor: r == null ? '—' : EtlCarga.milhar(r.total)),
        _Metrica(
          rotulo: 'Pontos Importados',
          valor: r == null ? '—' : EtlCarga.milhar(r.importadas),
          corValor: EtlColors.slate900,
        ),
      ),
      if (c.status == EtlCargaStatus.erro) ...[
        const SizedBox(height: 16),
        _Falha(mensagem: c.errorMessage, log: c.logTail),
      ],
      if (r != null) ...[
        const SizedBox(height: 20),
        CsvResumoImportacao(resumo: r, nomeArquivo: c.nomeArquivo, mostrarNumeros: false),
      ],
      // Sem linha nova o resumo acima já explica; não repete o aviso.
      if (c.status != EtlCargaStatus.erro && (r?.importadas ?? 0) > 0) ...[
        const SizedBox(height: 20),
        _LinhasImportadas(
          carga: c,
          carregar: carregarPontos ?? (id) => EtlService.listarPontosDaImportacao(id),
        ),
      ],
    ];
  }
}

// ─────────────────────────────── Cabeçalho ───────────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.carga, required this.onFechar});

  final EtlCarga carga;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    final bool ok = carga.status == EtlCargaStatus.concluido;
    final Color fundo = ok ? EtlColors.emerald50 : EtlColors.teal50;
    final Color borda = ok ? EtlColors.emerald200 : EtlColors.teal200;
    final Color texto = ok ? EtlColors.emerald700 : EtlColors.teal700;
    final Color ponto = ok ? EtlColors.emerald500 : EtlColors.teal500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: EtlColors.slate100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EtlColors.teal50,
              border: Border.all(color: EtlColors.teal100),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(carga.ehCsv ? Icons.description_outlined : Icons.dataset_outlined,
                size: 24, color: EtlColors.teal600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      carga.nomeArquivo,
                      style: etlText(18,
                          weight: FontWeight.w700,
                          color: EtlColors.slate900,
                          lineHeight: 28,
                          letterSpacing: -0.45,
                          mono: true),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: fundo,
                        border: Border.all(color: borda),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: ponto, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(carga.statusLabel,
                              style: etlText(12, weight: FontWeight.w600, color: texto, lineHeight: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: EtlColors.slate400),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Executado em ${carga.executadoEm ?? '—'}',
                        style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                      ),
                    ),
                  ],
                ),
                if (carga.ehCsv) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.add_location_alt_outlined, size: 14, color: EtlColors.slate400),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          carga.origemCsv,
                          style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                        ),
                      ),
                    ],
                  ),
                ],
                if (carga.municipios.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: EtlColors.slate400),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          MunicipioService.rotulosDe(carga.municipios),
                          style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          EtlBotaoIcone(icone: Icons.close, onTap: onFechar),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Métricas ───────────────────────────────

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.rotulo,
    required this.valor,
    this.corValor = EtlColors.slate800,
    this.tamanhoValor = 16,
    this.tooltip,
  });

  final String rotulo;
  final String valor;
  final Color corValor;
  final double tamanhoValor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget texto = Text(
      valor,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: etlText(tamanhoValor,
          weight: FontWeight.w700, color: corValor, lineHeight: tamanhoValor >= 16 ? 24 : 16),
    );
    if (tooltip != null) texto = Tooltip(message: tooltip!, child: texto);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EtlColors.slate50,
        border: Border.all(color: EtlColors.slate200a80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: etlText(11, weight: FontWeight.w500, color: EtlColors.slate500, lineHeight: 16.5)),
          const SizedBox(height: 4),
          texto,
        ],
      ),
    );
  }
}

// ─────────────────────────────── Camadas ───────────────────────────────

class _SecaoCamadas extends StatelessWidget {
  const _SecaoCamadas({required this.camadas});

  final List<EtlCamada> camadas;

  static const int _fNome = 4;
  static const int _fNum = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, size: 14, color: EtlColors.teal600),
            const SizedBox(width: 6),
            Text(
              'TABELAS CARREGADAS NO POSTGIS (${camadas.length})',
              style: etlText(12,
                  weight: FontWeight.w700, color: EtlColors.slate900, lineHeight: 16, letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (camadas.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: EtlColors.slate200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Nenhuma tabela registrada para esta carga até o momento.',
              style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: EtlColors.slate200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xCCF8FAFC), // slate-50/80
                    border: Border(bottom: BorderSide(color: EtlColors.slate200)),
                  ),
                  child: Row(
                    children: [
                      _cel(_fNome, 16, Text('Tabela PostGIS', style: _cab())),
                      _celNum(Tooltip(
                        message: 'Registros dos municípios selecionados que passaram pelos filtros.',
                        child: Text('Na cidade', style: _cab()),
                      )),
                      _celNum(Tooltip(
                        message:
                            'Subestações/transformadores fora dos municípios, gravados para manter os vínculos da rede.',
                        child: Text('Pais fora', style: _cab()),
                      )),
                      _celNum(Tooltip(
                        message: 'Registros inseridos no banco nesta execução.',
                        child: Text('Gravados', style: _cab()),
                      )),
                      _celNum(Tooltip(
                        message: 'Registros ignorados (já existentes no banco ou sem transformador).',
                        child: Text('Ignorados', style: _cab()),
                      )),
                    ],
                  ),
                ),
                for (int i = 0; i < camadas.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i == camadas.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: EtlColors.slate100)),
                    ),
                    child: Row(
                      children: [
                        _cel(
                          _fNome,
                          16,
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(color: EtlColors.teal500, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  camadas[i].nome,
                                  overflow: TextOverflow.ellipsis,
                                  style: etlText(12,
                                      weight: FontWeight.w500, color: EtlColors.slate800, lineHeight: 16, mono: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _celNum(_valor(camadas[i].naCidade)),
                        _celNum(_valor(camadas[i].paisForaDaArea)),
                        _celNum(_valor(camadas[i].gravados, destaque: true)),
                        _celNum(_valor(camadas[i].ignorados)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _valor(int n, {bool destaque = false}) => Text(
        EtlCarga.milhar(n),
        style: etlText(12,
            weight: destaque ? FontWeight.w700 : FontWeight.w500,
            color: destaque ? EtlColors.slate900 : EtlColors.slate700,
            lineHeight: 16),
      );

  static TextStyle _cab() => etlText(12, weight: FontWeight.w600, color: EtlColors.slate500, lineHeight: 16);

  static Widget _cel(int flex, double padEsq, Widget child) {
    return Expanded(
      flex: flex,
      child: Padding(padding: EdgeInsets.only(left: padEsq), child: child),
    );
  }

  static Widget _celNum(Widget child) {
    return Expanded(
      flex: _fNum,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 16),
        child: Align(alignment: Alignment.centerRight, child: child),
      ),
    );
  }
}

/// Motivo da falha e as últimas linhas do log do processamento (#TG-141),
/// para o ADM entender o erro sem precisar abrir o servidor.
class _Falha extends StatelessWidget {
  const _Falha({this.mensagem, this.log});

  final String? mensagem;
  final String? log;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  mensagem ?? 'O servidor não informou o motivo da falha.',
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
        ),
        if (log != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Log do processamento (últimas linhas)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EtlColors.slate900),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                log!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Linhas importadas (CSV) ─────────────────────────────

/// Pontos que a importação de CSV gravou (#TG-90), lidos do backend: filtro
/// por papel, tabela rolável e download no mesmo formato do CSV de entrada.
class _LinhasImportadas extends StatefulWidget {
  const _LinhasImportadas({required this.carga, required this.carregar});

  final EtlCarga carga;
  final CarregarPontosDaImportacao carregar;

  @override
  State<_LinhasImportadas> createState() => _LinhasImportadasState();
}

class _LinhasImportadasState extends State<_LinhasImportadas> {
  PontosDaImportacao? _lista;
  String? _erro;
  bool _carregando = true;

  /// Papel escolhido no filtro; null = todos.
  String? _papel;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final PontosDaImportacao lista = await widget.carregar(widget.carga.id);
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _carregando = false;
      });
    } on EtlUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as linhas importadas.';
      });
    }
  }

  Future<void> _baixar(PontosDaImportacao lista) async {
    final String base = widget.carga.nomeArquivo.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
    try {
      await salvarArquivo(nome: '${base}_importadas.csv', bytes: bytesCsvComBom(lista.comoCsv()));
    } catch (_) {
      // Download é um extra; a tabela continua na tela.
    }
  }

  @override
  Widget build(BuildContext context) {
    final PontosDaImportacao? lista = _lista;
    final TextStyle titulo = etlText(13, weight: FontWeight.w700, color: EtlColors.slate900, lineHeight: 20);

    if (_carregando) {
      return Row(
        children: [
          Text('Linhas importadas', style: titulo),
          const SizedBox(width: 10),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(EtlColors.teal600)),
          ),
        ],
      );
    }
    if (_erro != null || lista == null) {
      return EtlAvisoLinha(
        mensagem: _erro ?? 'Não foi possível carregar as linhas importadas.',
        erro: true,
        acao: TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
      );
    }
    if (lista.pontos.isEmpty) {
      final bool importouAlgo = (widget.carga.csv?.importadas ?? 0) > 0;
      return EtlAvisoLinha(
        mensagem: importouAlgo
            ? 'As linhas desta importação não estão ligadas a ela: foi feita antes de o '
                'histórico guardar os pontos de cada importação.'
            : 'Nenhuma linha nova foi gravada nesta importação.',
      );
    }

    final List<PontoImportado> visiveis =
        _papel == null ? lista.pontos : lista.pontos.where((p) => p.papel == _papel).toList();
    int contar(String papel) => lista.pontos.where((p) => p.papel == papel).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          children: [
            Text('Linhas importadas (${EtlCarga.milhar(lista.total)})', style: titulo),
            EtlBotaoLink(icone: Icons.download_outlined, label: 'Baixar .csv', onTap: () => _baixar(lista)),
          ],
        ),
        const SizedBox(height: 8),
        AppFilterChipRow(chips: [
          AppFilterChip(
            label: 'Todos (${lista.pontos.length})',
            selected: _papel == null,
            onTap: () => setState(() => _papel = null),
          ),
          for (final String papel in PontoImportado.papeis)
            if (contar(papel) > 0)
              AppFilterChip(
                label: '${PontoImportado.rotuloPapel(papel)} (${contar(papel)})',
                selected: _papel == papel,
                onTap: () => setState(() => _papel = papel),
              ),
        ]),
        const SizedBox(height: 8),
        EtlTabela(
          alturaMaxima: 320,
          cabecalho: const ['#', 'id', 'papel', 'latitude', 'longitude', 'descrição'],
          linhas: [
            for (int i = 0; i < visiveis.length; i++)
              [
                '${i + 1}',
                visiveis[i].id,
                PontoImportado.rotuloPapel(visiveis[i].papel),
                '${visiveis[i].latitude}',
                '${visiveis[i].longitude}',
                visiveis[i].descricao ?? '',
              ],
          ],
        ),
        if (lista.cortada) ...[
          const SizedBox(height: 6),
          Text(
            'Mostrando as primeiras ${EtlCarga.milhar(lista.pontos.length)} de ${EtlCarga.milhar(lista.total)} linhas.',
            style: etlText(11, color: EtlColors.slate500, lineHeight: 16),
          ),
        ],
      ],
    );
  }
}
