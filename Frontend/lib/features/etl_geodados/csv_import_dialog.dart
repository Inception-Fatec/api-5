import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';

import 'etl_theme.dart';
import 'models/csv_import_resumo.dart';
import 'services/csv_preview.dart';
import 'services/etl_service.dart';
import 'services/salvar_arquivo.dart';
import 'widgets/etl_modal.dart';
import 'widgets/seletor_municipio.dart';

/// Liga o [CsvImportPainel] ao rodapé do modal de envio: o botão
/// "Importar pontos" fica no rodapé, mas quem sabe se pode enviar (e quem
/// envia) é o painel. Avisa os ouvintes a cada mudança do painel.
class CsvImportController extends ChangeNotifier {
  _CsvImportPainelState? _painel;

  bool get podeEnviar => _painel?._podeEnviar ?? false;
  bool get enviando => _painel?._enviando ?? false;
  double get progresso => _painel?._progresso ?? 0;

  /// Resumo já recebido do backend (o painel está mostrando o resultado).
  CsvImportResumo? get resumo => _painel?._resumo;

  Future<void> enviar() async => _painel?._enviar();

  void _mudou() => notifyListeners();
}

/// Corpo do modal de envio para um .csv de pontos externos (#TG-90, RF-07):
/// coordenadas externas à BDGD para usar como candidato a gateway, ponto a
/// cobrir ou ponto de interesse.
///
/// O arquivo chega pronto (o modal único reconhece o .csv pela extensão);
/// aqui o ADM escolhe distribuidora e município, confere a prévia, importa
/// e vê o resumo com as linhas rejeitadas. Os pontos ainda não aparecem no
/// mapa nem entram no motor (#TG-91 / #TG-92).
class CsvImportPainel extends StatefulWidget {
  const CsvImportPainel({
    super.key,
    required this.nomeArquivo,
    required this.bytes,
    required this.onTrocarArquivo,
    this.onImportado,
    this.controller,
    this.distribuidorasService,
  });

  final String nomeArquivo;
  final Uint8List bytes;

  /// Volta para a área de arrastar (aceita .zip ou .csv de novo).
  final VoidCallback onTrocarArquivo;
  final ValueChanged<CsvImportResumo>? onImportado;
  final CsvImportController? controller;

  /// Para os testes; no app usa o serviço padrão.
  final DistribuidorasService? distribuidorasService;

  @override
  State<CsvImportPainel> createState() => _CsvImportPainelState();
}

class _CsvImportPainelState extends State<CsvImportPainel> {
  late final DistribuidorasService _distribuidorasService =
      widget.distribuidorasService ?? DistribuidorasService();
  late final PreviaCsv _previa = analisarCsv(decodificarCsv(widget.bytes));

  // Destino: o backend exige distribuidora e município (código IBGE).
  List<Distribuidora>? _distribuidoras;
  bool _carregandoDistribuidoras = true;
  String? _erroDistribuidoras;
  String? _distribuidora;
  List<String> _municipios = const <String>[];
  bool _carregandoMunicipios = false;
  String? _erroMunicipios;
  String? _municipio;

  bool _enviando = false;
  double _progresso = 0;
  String? _erro;
  CsvImportResumo? _resumo;
  bool _copiado = false;

  bool get _podeEnviar =>
      !_enviando &&
      _resumo == null &&
      _distribuidora != null &&
      _municipio != null &&
      _previa.podeEnviar;

  /// Toda mudança de estado também atualiza o rodapé do modal.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.controller?._mudou();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._painel = this;
    // Sem setState aqui: avisar o modal durante o build dele daria erro.
    _carregarDistribuidoras(inicial: true);
    // Nomes das cidades no seletor; se o IBGE falhar, mostra o código.
    MunicipioService.listar().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  @override
  void didUpdateWidget(CsvImportPainel antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.controller != widget.controller) {
      if (antigo.controller?._painel == this) antigo.controller?._painel = null;
      widget.controller?._painel = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._painel == this) widget.controller?._painel = null;
    super.dispose();
  }

  // ───────────────────────── Distribuidora e município ─────────────────────────

  Future<void> _carregarDistribuidoras({bool inicial = false}) async {
    if (!inicial) {
      setState(() {
        _carregandoDistribuidoras = true;
        _erroDistribuidoras = null;
      });
    }
    try {
      final List<Distribuidora> lista = await _distribuidorasService.listar();
      if (!mounted) return;
      setState(() {
        _distribuidoras = lista;
        _carregandoDistribuidoras = false;
      });
      // Com uma distribuidora só no banco, não faz o ADM escolher.
      if (lista.length == 1) await _escolherDistribuidora(lista.first.codigo);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoDistribuidoras = false;
        _erroDistribuidoras =
            'Não foi possível carregar as distribuidoras. Verifique a conexão com o servidor.';
      });
    }
  }

  Future<void> _escolherDistribuidora(String? codigo) async {
    setState(() {
      _distribuidora = codigo;
      _municipio = null;
      _municipios = const <String>[];
      _erroMunicipios = null;
      _carregandoMunicipios = codigo != null;
    });
    if (codigo == null) return;
    try {
      final List<int> codigos =
          await _distribuidorasService.codigosMunicipios(codigo);
      // O ADM pode ter trocado de distribuidora enquanto carregava.
      if (!mounted || _distribuidora != codigo) return;
      setState(() {
        _municipios = codigos.map((c) => c.toString()).toList();
        _carregandoMunicipios = false;
        if (_municipios.length == 1) _municipio = _municipios.first;
      });
    } catch (_) {
      if (!mounted || _distribuidora != codigo) return;
      setState(() {
        _carregandoMunicipios = false;
        _erroMunicipios = 'Não foi possível carregar os municípios dessa distribuidora.';
      });
    }
  }

  // ───────────────────────────── Envio ─────────────────────────────

  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    setState(() {
      _enviando = true;
      _progresso = 0;
      _erro = null;
    });
    try {
      final CsvImportResumo resumo = await EtlService.enviarCsv(
        bytes: widget.bytes,
        nomeArquivo: widget.nomeArquivo,
        distribuidora: _distribuidora!,
        municipio: _municipio!,
        onProgress: (p) {
          if (mounted) setState(() => _progresso = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _resumo = resumo;
        _copiado = false;
        _enviando = false;
      });
      widget.onImportado?.call(resumo);
    } on EtlUploadException catch (e) {
      _falhaNoEnvio(e.mensagem);
    } catch (e) {
      _falhaNoEnvio('Erro inesperado durante o envio: $e');
    }
  }

  void _falhaNoEnvio(String mensagem) {
    if (!mounted) return;
    // Mantém o arquivo: "Tentar de novo" reenvia sem escolher outra vez.
    setState(() {
      _enviando = false;
      _erro = mensagem;
    });
  }

  Future<void> _copiarRejeicoes() async {
    final CsvImportResumo? r = _resumo;
    if (r == null) return;
    await Clipboard.setData(ClipboardData(text: r.rejeicoesCsv()));
    if (mounted) setState(() => _copiado = true);
  }

  Future<void> _baixarRejeicoes() async {
    final CsvImportResumo? r = _resumo;
    if (r == null) return;
    final String base =
        widget.nomeArquivo.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
    try {
      await salvarArquivo(
          nome: '${base}_rejeitadas.csv', bytes: bytesCsvComBom(r.rejeicoesCsv()));
    } catch (_) {
      // Download é um extra; "Copiar" continua disponível.
    }
  }

  // ───────────────────────────── Tela ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final CsvImportResumo? resumo = _resumo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: resumo != null ? _conteudoResumo(resumo) : _conteudoFormulario(),
    );
  }

  List<Widget> _conteudoFormulario() {
    final PreviaCsv previa = _previa;
    return [
      EtlCardArquivo(
        nome: widget.nomeArquivo,
        icone: Icons.description_outlined,
        formato: '.csv · ${previa.totalLinhas} ${previa.totalLinhas == 1 ? 'linha' : 'linhas'}',
        status: previa.podeEnviar ? 'Pronto para importar' : 'Verifique os avisos abaixo',
        valido: previa.podeEnviar,
        onSubstituir: _enviando ? null : widget.onTrocarArquivo,
      ),
      const SizedBox(height: 16),
      _destino(),
      const SizedBox(height: 16),
      _TabelaPrevia(previa: previa),
      if (_enviando) ...[
        const SizedBox(height: 16),
        EtlCardProgresso(
          enviando: true,
          progresso: _progresso,
          texto: _progresso >= 1
              ? 'Validando as linhas e gravando os pontos...'
              : 'Enviando arquivo...',
        ),
      ],
      if (_erro != null) ...[
        const SizedBox(height: 16),
        EtlCaixaErro(
          titulo: 'Falha na importação',
          mensagem: _erro!,
          rotuloAcao: 'Tentar de novo',
          onTentar: _podeEnviar ? _enviar : null,
        ),
      ],
    ];
  }

  /// Seletores de distribuidora e município (lado a lado no desktop,
  /// empilhados no celular).
  Widget _destino() {
    if (_carregandoDistribuidoras) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(EtlColors.teal600)),
          ),
          const SizedBox(width: 8),
          Text('Carregando distribuidoras...',
              style: etlText(12, color: EtlColors.slate500, lineHeight: 16)),
        ],
      );
    }
    if (_erroDistribuidoras != null) {
      return _AvisoLinha(
        mensagem: _erroDistribuidoras!,
        erro: true,
        acao: TextButton(
            onPressed: _carregarDistribuidoras, child: const Text('Tentar novamente')),
      );
    }
    final List<Distribuidora> lista = _distribuidoras ?? const <Distribuidora>[];
    if (lista.isEmpty) {
      return const _AvisoLinha(
        mensagem: 'Nenhuma distribuidora com dados no banco. Envie antes o .zip com a '
            'BDGD da distribuidora (neste mesmo botão "Enviar arquivo") e depois importe os pontos.',
        erro: true,
      );
    }

    final Widget campoDistribuidora = _Campo(
      rotulo: 'Distribuidora',
      child: DropdownButtonFormField<String>(
        // initialValue só vale na criação: a chave muda junto com o valor
        // para a pré-seleção (uma distribuidora só) aparecer no campo.
        key: ValueKey('csv-distribuidora-$_distribuidora'),
        initialValue: _distribuidora,
        isExpanded: true,
        decoration: _decoracao('Selecione a distribuidora'),
        style: etlText(13, color: EtlColors.slate800, lineHeight: 20),
        items: [
          for (final Distribuidora d in lista)
            DropdownMenuItem<String>(
              value: d.codigo,
              child: Text(d.rotulo, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _enviando ? null : _escolherDistribuidora,
      ),
    );

    // Ordenados pelo nome (quando a lista do IBGE já chegou).
    final List<String> municipios = List<String>.of(_municipios)
      ..sort((a, b) => MunicipioService.rotuloDe(a).compareTo(MunicipioService.rotuloDe(b)));
    final Widget campoMunicipio = _Campo(
      rotulo: 'Município',
      child: DropdownButtonFormField<String>(
        key: ValueKey('csv-municipio-$_distribuidora-$_municipio-${_municipios.length}'),
        initialValue: _municipio,
        isExpanded: true,
        decoration: _decoracao(_distribuidora == null
            ? 'Escolha a distribuidora antes'
            : (_carregandoMunicipios ? 'Carregando municípios...' : 'Selecione o município')),
        style: etlText(13, color: EtlColors.slate800, lineHeight: 20),
        items: [
          for (final String c in municipios)
            DropdownMenuItem<String>(
              value: c,
              child: Text(
                MunicipioService.rotuloDe(c) == c ? c : '${MunicipioService.rotuloDe(c)} ($c)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _enviando || municipios.isEmpty
            ? null
            : (v) => setState(() => _municipio = v),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [campoDistribuidora, const SizedBox(height: 12), campoMunicipio],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: campoDistribuidora),
              const SizedBox(width: 12),
              Expanded(child: campoMunicipio),
            ],
          );
        }),
        if (_erroMunicipios != null) ...[
          const SizedBox(height: 8),
          _AvisoLinha(
            mensagem: _erroMunicipios!,
            erro: true,
            acao: TextButton(
              onPressed: () => _escolherDistribuidora(_distribuidora),
              child: const Text('Tentar novamente'),
            ),
          ),
        ] else if (_distribuidora != null &&
            !_carregandoMunicipios &&
            _municipios.isEmpty) ...[
          const SizedBox(height: 8),
          const _AvisoLinha(
            mensagem: 'Essa distribuidora não tem municípios carregados no banco.',
            erro: true,
          ),
        ],
      ],
    );
  }

  static InputDecoration _decoracao(String dica) => InputDecoration(
        isDense: true,
        hintText: dica,
        hintStyle: etlText(13, color: EtlColors.slate400, lineHeight: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EtlColors.slate200),
        ),
      );

  List<Widget> _conteudoResumo(CsvImportResumo r) {
    return [
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
      Text(r.texto,
          style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16)),
      if (r.soJaExistentes) ...[
        const SizedBox(height: 12),
        _AvisoLinha(
          mensagem: 'Nenhum ponto novo: ${r.jaExistentes == 1 ? 'o ponto válido já tinha' : 'os ${r.jaExistentes} pontos válidos já tinham'} '
              'sido importado${r.jaExistentes == 1 ? '' : 's'} para essa distribuidora. '
              'O id é único por distribuidora e pontos já existentes não são alterados.',
        ),
      ] else if (r.jaExistentes > 0) ...[
        const SizedBox(height: 12),
        _AvisoLinha(
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
          copiado: _copiado,
          onCopiar: _copiarRejeicoes,
          onBaixar: _baixarRejeicoes,
        ),
      ],
    ];
  }
}

// ───────────────────────────── Peças do painel de CSV ─────────────────────────────

class _Campo extends StatelessWidget {
  const _Campo({required this.rotulo, required this.child});

  final String rotulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(rotulo,
            style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 16)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Aviso de uma linha: âmbar (atenção) ou rosa ([erro]).
class _AvisoLinha extends StatelessWidget {
  const _AvisoLinha({required this.mensagem, this.erro = false, this.acao});

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

/// Cabeçalho + primeiras linhas do arquivo, com os avisos da prévia.
class _TabelaPrevia extends StatelessWidget {
  const _TabelaPrevia({required this.previa});

  final PreviaCsv previa;

  @override
  Widget build(BuildContext context) {
    final int colunas = [
      previa.cabecalho.length,
      for (final l in previa.linhas) l.celulas.length,
    ].reduce((a, b) => a > b ? a : b);
    final Set<String> obrigatorias = kColunasObrigatoriasCsv.toSet();

    TableRow linha(List<String> celulas,
        {required bool cabecalho, String numero = '', bool alerta = false}) {
      return TableRow(
        decoration: BoxDecoration(
          color: cabecalho ? EtlColors.slate100 : (alerta ? EtlColors.amber50 : Colors.white),
        ),
        children: [
          _celula(numero, cabecalho: cabecalho, mudo: true),
          for (int i = 0; i < colunas; i++)
            _celula(
              i < celulas.length ? celulas[i] : '',
              cabecalho: cabecalho,
              destaque: cabecalho &&
                  i < celulas.length &&
                  obrigatorias.contains(celulas[i].toLowerCase()),
            ),
        ],
      );
    }

    final int mostradas = previa.linhas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mostradas < previa.totalLinhas
              ? 'Prévia: cabeçalho e primeiras $mostradas de ${previa.totalLinhas} linhas'
              : 'Prévia do arquivo',
          style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 16),
        ),
        const SizedBox(height: 8),
        for (final String aviso in previa.avisos) ...[
          _AvisoLinha(mensagem: aviso, erro: true),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: EtlColors.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: const TableBorder(
                  horizontalInside: BorderSide(color: EtlColors.slate100),
                  verticalInside: BorderSide(color: EtlColors.slate100),
                ),
                children: [
                  linha(previa.cabecalho, cabecalho: true, numero: '#'),
                  for (final l in previa.linhas)
                    linha(l.celulas,
                        cabecalho: false,
                        numero: '${l.numero}',
                        alerta: previa.linhaDesalinhada(l)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          previa.linhas.any(previa.linhaDesalinhada)
              ? 'Linhas em amarelo têm um número de colunas diferente do cabeçalho e serão rejeitadas. '
                  'A validação completa é feita ao importar.'
              : 'A validação completa (coordenadas, papel, ids repetidos) é feita ao importar.',
          style: etlText(11, color: EtlColors.slate500, lineHeight: 16),
        ),
      ],
    );
  }

  static Widget _celula(String texto,
      {required bool cabecalho, bool mudo = false, bool destaque = false}) {
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
            weight: cabecalho ? FontWeight.w600 : FontWeight.w400,
            color: mudo
                ? EtlColors.slate400
                : (destaque
                    ? EtlColors.teal800
                    : (cabecalho ? EtlColors.slate700 : EtlColors.slate800)),
            lineHeight: 16,
            mono: !mudo,
          ),
        ),
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
    required this.copiado,
    required this.onCopiar,
    required this.onBaixar,
  });

  final List<CsvRejeicao> rejeicoes;
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
            Text('Linhas rejeitadas (${rejeicoes.length})',
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
      ],
    );
  }
}
