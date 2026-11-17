import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';

import 'etl_theme.dart';
import 'models/csv_import_resumo.dart';
import 'services/csv_preview.dart';
import 'services/etl_service.dart';
import 'widgets/csv_resumo.dart';
import 'widgets/etl_modal.dart';
import 'widgets/etl_tabela.dart';
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
    this.onEnviado,
    this.controller,
    this.distribuidorasService,
  });

  final String nomeArquivo;
  final Uint8List bytes;

  /// Volta para a área de arrastar (aceita .zip ou .csv de novo).
  final VoidCallback onTrocarArquivo;
  final ValueChanged<CsvImportResumo>? onImportado;

  /// Chamado ao fim de cada envio (sucesso ou falha): a tentativa vira um
  /// item do histórico de cargas e a tela precisa recarregá-lo.
  final VoidCallback? onEnviado;
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

  // Distribuidora personalizada, sem BDGD (#TG-151).
  static const String _kNova = '__nova__';
  bool _novaDistribuidora = false;
  final TextEditingController _codigoNova = TextEditingController();
  final TextEditingController _nomeNova = TextEditingController();
  bool _cadastrando = false;
  String? _erroNova;

  bool _enviando = false;
  double _progresso = 0;
  String? _erro;
  CsvImportResumo? _resumo;

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
    _codigoNova.dispose();
    _nomeNova.dispose();
    super.dispose();
  }

  // ───────────────────────── Distribuidora e município ─────────────────────────

  Future<void> _carregarDistribuidoras({bool inicial = false, String? selecionar}) async {
    if (!inicial) {
      setState(() {
        _carregandoDistribuidoras = true;
        _erroDistribuidoras = null;
      });
    }
    try {
      // Inclui as cadastradas ainda sem dados (#TG-151).
      final List<Distribuidora> lista =
          await _distribuidorasService.listar(incluirCadastradas: true);
      if (!mounted) return;
      setState(() {
        _distribuidoras = lista;
        _carregandoDistribuidoras = false;
      });
      if (selecionar != null) {
        await _escolherDistribuidora(selecionar);
      } else if (lista.length == 1) {
        // Com uma distribuidora só no banco, não faz o ADM escolher.
        await _escolherDistribuidora(lista.first.codigo);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoDistribuidoras = false;
        _erroDistribuidoras =
            'Não foi possível carregar as distribuidoras. Verifique a conexão com o servidor.';
      });
    }
  }

  /// Cadastra a distribuidora digitada e já a seleciona (#TG-151).
  Future<void> _cadastrarDistribuidora() async {
    final String codigo = _codigoNova.text.trim();
    final String nome = _nomeNova.text.trim();
    if (!RegExp(r'^\d{1,10}$').hasMatch(codigo)) {
      setState(() => _erroNova = 'O código deve ter só números (até 10 dígitos).');
      return;
    }
    if (nome.isEmpty) {
      setState(() => _erroNova = 'Informe o nome da distribuidora.');
      return;
    }
    setState(() {
      _cadastrando = true;
      _erroNova = null;
    });
    try {
      await _distribuidorasService.cadastrar(codigo: codigo, nome: nome);
      if (!mounted) return;
      setState(() {
        _cadastrando = false;
        _novaDistribuidora = false;
        _codigoNova.clear();
        _nomeNova.clear();
      });
      await _carregarDistribuidoras(selecionar: codigo);
    } catch (e) {
      if (!mounted) return;
      // Ex.: "Já existe uma distribuidora com o código 391."
      setState(() {
        _cadastrando = false;
        _erroNova = '$e';
      });
    }
  }

  Future<void> _escolherDistribuidora(String? codigo) async {
    if (codigo == _kNova) {
      setState(() {
        _novaDistribuidora = true;
        _distribuidora = null;
        _municipio = null;
        _municipios = const <String>[];
        _erroMunicipios = null;
      });
      return;
    }
    setState(() {
      _novaDistribuidora = false;
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
        _enviando = false;
      });
      widget.onImportado?.call(resumo);
    } on EtlUploadException catch (e) {
      _falhaNoEnvio(e.mensagem);
    } catch (e) {
      _falhaNoEnvio('Erro inesperado durante o envio: $e');
    } finally {
      // Com sucesso ou falha, o backend registrou a tentativa no histórico.
      widget.onEnviado?.call();
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

  // ───────────────────────────── Tela ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final CsvImportResumo? resumo = _resumo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: resumo != null
          ? [CsvResumoImportacao(resumo: resumo, nomeArquivo: widget.nomeArquivo)]
          : _conteudoFormulario(),
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
      return EtlAvisoLinha(
        mensagem: _erroDistribuidoras!,
        erro: true,
        acao: TextButton(
            onPressed: _carregarDistribuidoras, child: const Text('Tentar novamente')),
      );
    }
    final List<Distribuidora> lista = _distribuidoras ?? const <Distribuidora>[];

    final Widget campoDistribuidora = _Campo(
      rotulo: 'Distribuidora',
      child: DropdownButtonFormField<String>(
        // initialValue só vale na criação: a chave muda junto com o valor
        // para a pré-seleção (uma distribuidora só) aparecer no campo.
        key: ValueKey('csv-distribuidora-$_distribuidora-$_novaDistribuidora-${lista.length}'),
        initialValue: _novaDistribuidora ? _kNova : _distribuidora,
        isExpanded: true,
        decoration: _decoracao('Selecione a distribuidora'),
        style: etlText(13, color: EtlColors.slate800, lineHeight: 20),
        items: [
          for (final Distribuidora d in lista)
            DropdownMenuItem<String>(
              value: d.codigo,
              child: Text(d.temRede ? d.rotulo : '${d.rotulo} · sem BDGD',
                  overflow: TextOverflow.ellipsis),
            ),
          const DropdownMenuItem<String>(
            value: _kNova,
            child: Text('+ Outra distribuidora...', overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: _enviando ? null : _escolherDistribuidora,
      ),
    );

    final Widget campoMunicipio = _Campo(
      rotulo: 'Município',
      child: _CampoMunicipio(
        // Recria o campo ao trocar de distribuidora ou pré-selecionar a cidade.
        key: ValueKey('csv-municipio-$_distribuidora-$_municipio-${_municipios.length}'),
        selecionado: _municipio,
        comDados: _municipios.toSet(),
        habilitado: !_enviando && _distribuidora != null,
        dica: _distribuidora == null
            ? 'Escolha a distribuidora antes'
            : (_carregandoMunicipios ? 'Carregando municípios...' : 'Digite o nome do município'),
        decoracao: _decoracao,
        onEscolher: (c) => setState(() => _municipio = c),
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
        if (_novaDistribuidora) ...[
          const SizedBox(height: 12),
          _formNovaDistribuidora(),
        ],
        if (_erroMunicipios != null) ...[
          const SizedBox(height: 8),
          EtlAvisoLinha(
            mensagem: _erroMunicipios!,
            erro: true,
            acao: TextButton(
              onPressed: () => _escolherDistribuidora(_distribuidora),
              child: const Text('Tentar novamente'),
            ),
          ),
        ] else if (_distribuidora != null &&
            !_carregandoMunicipios &&
            _municipio != null &&
            !_municipios.contains(_municipio)) ...[
          const SizedBox(height: 8),
          const EtlAvisoLinha(
            mensagem: 'Esse município ainda não tem dados dessa distribuidora: os pontos do '
                'CSV vão formar uma rede independente (sem a rede da BDGD).',
          ),
        ],
      ],
    );
  }

  /// Código e nome da distribuidora nova (#TG-151).
  Widget _formNovaDistribuidora() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EtlColors.slate50,
        border: Border.all(color: EtlColors.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nova distribuidora (rede sem BDGD carregada)',
              style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 16)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  key: const Key('nova-dist-codigo'),
                  controller: _codigoNova,
                  enabled: !_cadastrando,
                  keyboardType: TextInputType.number,
                  decoration: _decoracao('Código'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('nova-dist-nome'),
                  controller: _nomeNova,
                  enabled: !_cadastrando,
                  decoration: _decoracao('Nome'),
                ),
              ),
            ],
          ),
          if (_erroNova != null) ...[
            const SizedBox(height: 8),
            EtlAvisoLinha(mensagem: _erroNova!, erro: true),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('nova-dist-cadastrar'),
              onPressed: _cadastrando ? null : _cadastrarDistribuidora,
              style: FilledButton.styleFrom(backgroundColor: EtlColors.teal600),
              child: Text(_cadastrando ? 'Cadastrando...' : 'Cadastrar distribuidora'),
            ),
          ),
        ],
      ),
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

/// Cabeçalho + primeiras linhas do arquivo, com os avisos da prévia.
class _TabelaPrevia extends StatelessWidget {
  const _TabelaPrevia({required this.previa});

  final PreviaCsv previa;

  @override
  Widget build(BuildContext context) {
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
          EtlAvisoLinha(mensagem: aviso, erro: true),
          const SizedBox(height: 8),
        ],
        EtlTabela(
          cabecalho: ['#', ...previa.cabecalho],
          linhas: [
            for (final l in previa.linhas) ['${l.numero}', ...l.celulas],
          ],
          colunasDestacadas: kColunasObrigatoriasCsv.toSet(),
          linhasEmAlerta: {
            for (int i = 0; i < previa.linhas.length; i++)
              if (previa.linhaDesalinhada(previa.linhas[i])) i,
          },
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
}

/// Município por busca em todas as cidades do IBGE (#TG-151). As que já têm
/// dados da distribuidora aparecem primeiro, marcadas.
class _CampoMunicipio extends StatelessWidget {
  const _CampoMunicipio({
    super.key,
    required this.selecionado,
    required this.comDados,
    required this.habilitado,
    required this.dica,
    required this.decoracao,
    required this.onEscolher,
  });

  final String? selecionado;
  final Set<String> comDados;
  final bool habilitado;
  final String dica;
  final InputDecoration Function(String) decoracao;
  final ValueChanged<String?> onEscolher;

  static const int _maxOpcoes = 30;

  static String _rotulo(Municipio m) => '${m.nome} - ${m.uf}';

  @override
  Widget build(BuildContext context) {
    final List<Municipio> todos = MunicipioService.cache;
    final Municipio? inicial =
        selecionado == null ? null : todos.where((m) => m.codigo == selecionado).firstOrNull;
    return Autocomplete<Municipio>(
      initialValue: TextEditingValue(
          text: inicial != null ? _rotulo(inicial) : (selecionado ?? '')),
      displayStringForOption: _rotulo,
      optionsBuilder: (TextEditingValue v) {
        final String termo = MunicipioService.normalizar(v.text.trim());
        final List<Municipio> achados = [
          for (final m in todos)
            if (termo.isEmpty ? comDados.contains(m.codigo) : MunicipioService.normalizar(_rotulo(m)).contains(termo))
              m,
        ]..sort((a, b) {
            final da = comDados.contains(a.codigo), db = comDados.contains(b.codigo);
            if (da != db) return da ? -1 : 1;
            return a.nome.compareTo(b.nome);
          });
        return achados.take(_maxOpcoes);
      },
      onSelected: (m) => onEscolher(m.codigo),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        key: const Key('csv-municipio-busca'),
        controller: controller,
        focusNode: focus,
        enabled: habilitado,
        onChanged: (_) {
          // Apagou ou mudou o texto: a cidade escolhida deixa de valer.
          if (selecionado != null) onEscolher(null);
        },
        decoration: decoracao(dica),
      ),
      optionsViewBuilder: (context, onSelect, opcoes) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final m in opcoes)
                  ListTile(
                    dense: true,
                    title: Text(_rotulo(m)),
                    trailing: comDados.contains(m.codigo)
                        ? Text('com dados',
                            style: etlText(11, color: EtlColors.teal700, lineHeight: 14))
                        : null,
                    onTap: () => onSelect(m),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
