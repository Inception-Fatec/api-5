import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';

import 'csv_import_dialog.dart';
import 'etl_theme.dart';
import 'models/csv_import_resumo.dart';
import 'models/etl_carga.dart';
import 'services/arquivo_local.dart';
import 'services/csv_preview.dart';
import 'services/etl_service.dart';
import 'services/salvar_arquivo.dart';
import 'widgets/etl_buttons.dart';
import 'widgets/escolha_municipios.dart';
import 'widgets/etl_modal.dart';

enum _Fase { vazio, pronto, enviando, escolhendo, iniciando, erro }

/// Tipos aceitos pelo modal único de envio (#TG-90).
enum TipoArquivoEnvio {
  /// File Geodatabase da BDGD compactado.
  zip,

  /// Pontos externos (candidatos, pontos a cobrir, de interesse).
  csv,
}

/// Mensagem para qualquer arquivo que não seja .zip nem .csv.
const String kMensagemFormatoInvalido =
    'Envie um .zip com a BDGD ou um .csv de pontos.';

/// O navegador não entregou o arquivo solto (ex.: arrastado do painel de
/// downloads do Opera, que manda só um link).
const String kMensagemSoltarSemArquivo =
    'O navegador não entregou o arquivo arrastado. Isso acontece ao arrastar '
    'do painel de downloads do navegador: arraste o arquivo a partir da pasta '
    '(Explorador de Arquivos) ou clique na área para selecionar.';

/// O tipo do arquivo pela extensão (o backend também valida pelo nome).
/// `null` quando não é nenhum dos dois.
TipoArquivoEnvio? tipoDoArquivo(String nome) {
  final String n = nome.toLowerCase();
  if (n.endsWith('.zip')) return TipoArquivoEnvio.zip;
  if (n.endsWith('.csv')) return TipoArquivoEnvio.csv;
  return null;
}

/// O que o modal devolve: a carga do .zip e/ou o resultado dos CSVs
/// importados (dá para importar mais de um arquivo antes de fechar).
class ResultadoEnvio {
  const ResultadoEnvio({this.carga, this.csv, this.pontosImportados = 0});

  final EtlCarga? carga;

  /// Resumo do último CSV importado.
  final CsvImportResumo? csv;

  /// Soma das linhas importadas em todos os CSVs desta abertura do modal.
  final int pontosImportados;
}

/// Modal único "Enviar arquivo" da tela de ETL (#TG-90).
///
/// Uso: `final ResultadoEnvio? r = await UploadModalDialog.show(context);`
/// Devolve `null` se nada foi enviado.
///
/// Aceita .zip ou .csv e segue o fluxo certo pela extensão, sem o ADM
/// precisar escolher o tipo antes:
/// - .zip (BDGD), em dois passos (#TG-143): envia, o backend lê a .gdb e
///   devolve os municípios; o ADM escolhe e inicia a carga. Com
///   [aguardando], o modal abre direto no passo 2 de uma carga já enviada.
/// - .csv (pontos externos): o corpo vira o [CsvImportPainel].
class UploadModalDialog extends StatefulWidget {
  const UploadModalDialog({super.key, this.aguardando, this.distribuidorasService});

  final EtlCarga? aguardando;

  /// Para os testes do fluxo de CSV; no app usa o serviço padrão.
  final DistribuidorasService? distribuidorasService;

  static Future<ResultadoEnvio?> show(BuildContext context, {EtlCarga? aguardando}) =>
      mostrarModalEtl<ResultadoEnvio>(
          context, UploadModalDialog(aguardando: aguardando));

  @override
  State<UploadModalDialog> createState() => _UploadModalDialogState();
}

class _UploadModalDialogState extends State<UploadModalDialog> {
  _Fase _fase = _Fase.vazio;
  String? _nome;
  String? _caminho;
  ArquivoLocal? _arquivoNavegador;
  double _progresso = 0;
  String? _erro;

  /// Carga devolvida pela inspeção (aguardando a escolha dos municípios).
  EtlCarga? _carga;
  Set<String> _escolhidos = <String>{};

  // Modo CSV: o arquivo já lido e o painel que cuida do resto.
  String? _csvNome;
  Uint8List? _csvBytes;

  /// Muda a cada .csv escolhido, para o painel começar do zero.
  int _csvChave = 0;
  final CsvImportController _csv = CsvImportController();
  CsvImportResumo? _ultimoResumo;
  int _pontosImportados = 0;
  String? _avisoModelo;

  /// Arquivo sendo arrastado sobre o modal (destaca a área tracejada).
  bool _arrastando = false;

  bool get _modoCsv => _csvBytes != null;

  bool get _ocupado =>
      _fase == _Fase.enviando || _fase == _Fase.iniciando || _csv.enviando;

  /// Etapa 2: o arquivo já foi lido pelo backend e falta escolher as cidades.
  bool get _naEscolha => _carga?.inspecao != null;

  @override
  void initState() {
    super.initState();
    _csv.addListener(_aoMudarCsv);
    if (envioPeloNavegador) {
      prepararArquivosSoltos();
      aoSoltarNoNavegador = _aoSoltarNoNavegador;
    }
    final EtlCarga? aguardando = widget.aguardando;
    if (aguardando != null) {
      _carga = aguardando;
      _nome = aguardando.nomeArquivo;
      _fase = _Fase.escolhendo;
    }
  }

  @override
  void dispose() {
    if (aoSoltarNoNavegador == _aoSoltarNoNavegador) aoSoltarNoNavegador = null;
    _csv
      ..removeListener(_aoMudarCsv)
      ..dispose();
    super.dispose();
  }

  /// O painel de CSV mudou (enviando, pode enviar, resumo): refaz o rodapé.
  void _aoMudarCsv() {
    if (mounted) setState(() {});
  }

  /// Na web o arquivo é uma referência do navegador (sem ler os bytes para
  /// a memória); nas demais plataformas, o caminho no disco (#TG-141).
  bool get _temArquivo => _caminho != null || _arquivoNavegador != null;

  ResultadoEnvio? _resultado({EtlCarga? carga}) {
    final EtlCarga? c = carga ?? _carga;
    if (c == null && _ultimoResumo == null) return null;
    return ResultadoEnvio(carga: c, csv: _ultimoResumo, pontosImportados: _pontosImportados);
  }

  /// Fechar na etapa de escolha mantém o upload no histórico como
  /// "Aguardando escolha" (dá para retomar pelo card); "Descartar" apaga.
  void _fechar() {
    if (_ocupado) return;
    Navigator.of(context).pop(_resultado());
  }

  Future<void> _descartar() async {
    final EtlCarga? carga = _carga;
    if (carga == null || _ocupado) return;
    setState(() => _fase = _Fase.iniciando);
    try {
      final EtlCarga cancelada = await EtlService.cancelarCarga(carga);
      if (!mounted) return;
      Navigator.of(context).pop(_resultado(carga: cancelada));
    } on EtlUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = e.mensagem;
      });
    }
  }

  Future<void> _escolherArquivo() async {
    if (_ocupado || _naEscolha) return;
    try {
      if (envioPeloNavegador) {
        final ArquivoLocal? arquivo =
            await escolherArquivoNoNavegador(aceitos: '.zip,.csv');
        if (arquivo == null || !mounted) return;
        await _selecionarArquivo(nome: arquivo.nome, arquivo: arquivo);
        return;
      }
      final FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip', 'csv'],
        allowMultiple: false,
      );
      if (resultado == null || resultado.files.isEmpty) return;
      final file = resultado.files.first;
      if (file.path == null) {
        throw const EtlUploadException(
            'Não foi possível ler o arquivo selecionado.');
      }
      await _selecionarArquivo(nome: file.name, caminho: file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = 'Não foi possível abrir o seletor de arquivos: $e';
      });
    }
  }

  /// Web: o arquivo vem direto do evento `drop` do navegador. Só conta se o
  /// arquivo foi solto sobre o modal ([_arrastando], que o DropTarget liga
  /// pela posição do cursor).
  void _aoSoltarNoNavegador(List<ArquivoLocal> arquivos) {
    if (!mounted) return;
    final bool sobreOModal = _arrastando;
    if (_arrastando) setState(() => _arrastando = false);
    if (!sobreOModal || _ocupado || _naEscolha || _modoCsv) return;
    if (arquivos.isEmpty) {
      setState(() {
        _fase = _Fase.erro;
        _erro = kMensagemSoltarSemArquivo;
      });
      return;
    }
    _selecionarArquivo(nome: arquivos.first.nome, arquivo: arquivos.first);
  }

  Future<void> _selecionarSolto(DropItem item) async {
    if (_ocupado || _naEscolha || _modoCsv) return;
    // Na web o "path" do arquivo solto é uma URL blob: pega o arquivo por ela,
    // sem copiar o conteúdo para a memória do app.
    if (envioPeloNavegador) {
      final ArquivoLocal arquivo;
      try {
        arquivo = await arquivoDeUrlBlob(item.path, item.name);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _fase = _Fase.erro;
          _erro = 'Não foi possível ler o arquivo: $e';
        });
        return;
      }
      if (!mounted) return;
      await _selecionarArquivo(nome: item.name, arquivo: arquivo);
      return;
    }
    final String nome = item.path.split(RegExp(r'[/\\]')).last;
    await _selecionarArquivo(nome: nome, caminho: item.path);
  }

  /// Decide o fluxo pela extensão: .zip segue a BDGD, .csv abre o painel
  /// de pontos, qualquer outro mostra a mensagem de formato.
  Future<void> _selecionarArquivo({
    required String nome,
    String? caminho,
    ArquivoLocal? arquivo,
  }) async {
    if (_ocupado) return;

    switch (tipoDoArquivo(nome)) {
      case null:
        setState(() {
          _fase = _Fase.erro;
          _erro = kMensagemFormatoInvalido;
        });
        return;
      case TipoArquivoEnvio.csv:
        await _selecionarCsv(nome: nome, caminho: caminho, arquivo: arquivo);
        return;
      case TipoArquivoEnvio.zip:
        break;
    }

    String? problema;
    try {
      problema = arquivo != null
          ? await EtlService.validarEstruturaZipArquivo(arquivo)
          : await EtlService.validarEstruturaZip(caminho!);
    } catch (e) {
      problema = 'Não foi possível ler o arquivo: $e';
    }
    if (!mounted) return;

    if (problema != null) {
      setState(() {
        _fase = _Fase.erro;
        _erro = problema;
      });
      return;
    }

    setState(() {
      _nome = nome;
      _caminho = caminho;
      _arquivoNavegador = arquivo;
      _progresso = 1;
      _erro = null;
      _fase = _Fase.pronto;
    });
  }

  /// O CSV é pequeno: lê os bytes (também na web) para a prévia e o envio.
  Future<void> _selecionarCsv({
    required String nome,
    String? caminho,
    ArquivoLocal? arquivo,
  }) async {
    final Uint8List bytes;
    try {
      bytes = arquivo != null
          ? await arquivo.lerTrecho(0, arquivo.tamanho)
          : await EtlService.lerArquivo(caminho!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = 'Não foi possível ler o arquivo: $e';
      });
      return;
    }
    if (!mounted) return;

    final String? problema = validarArquivoCsv(nome, bytes);
    if (problema != null) {
      setState(() {
        _fase = _Fase.erro;
        _erro = problema;
      });
      return;
    }

    setState(() {
      // Um .zip escolhido antes (e ainda não enviado) é deixado de lado.
      _nome = null;
      _caminho = null;
      _arquivoNavegador = null;
      _progresso = 0;
      _erro = null;
      _fase = _Fase.vazio;
      _csvNome = nome;
      _csvBytes = bytes;
      _csvChave++;
    });
  }

  /// "Trocar arquivo" / "Importar outro arquivo": volta para a área de
  /// arrastar, que aceita .zip ou .csv de novo.
  void _voltarParaArquivo() {
    if (_ocupado) return;
    setState(() {
      _csvNome = null;
      _csvBytes = null;
      _erro = null;
      _fase = _Fase.vazio;
    });
  }

  void _aoImportarCsv(CsvImportResumo resumo) {
    _ultimoResumo = resumo;
    _pontosImportados += resumo.importadas;
  }

  Future<void> _baixarModelo() async {
    try {
      final bool salvo =
          await salvarArquivo(nome: kNomeModeloCsv, bytes: bytesModeloCsv());
      if (!mounted) return;
      setState(() => _avisoModelo = salvo ? 'Modelo $kNomeModeloCsv baixado.' : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _avisoModelo = 'Não foi possível salvar o modelo: $e');
    }
  }

  /// Etapa 1: envia o arquivo; o backend descompacta e lê a .gdb.
  Future<void> _enviar() async {
    final String? nome = _nome;
    if (!_temArquivo || nome == null || _ocupado) return;

    setState(() {
      _fase = _Fase.enviando;
      _progresso = 0;
      _erro = null;
    });

    try {
      final EtlCarga carga = await EtlService.enviarZip(
        caminho: _caminho,
        arquivoNavegador: _arquivoNavegador,
        nomeArquivo: nome,
        onProgress: (p) {
          if (mounted) setState(() => _progresso = p);
        },
      );
      if (!mounted) return;
      if (carga.inspecao == null) {
        // Backend antigo (carga direta): nada a escolher.
        Navigator.of(context).pop(_resultado(carga: carga));
        return;
      }
      setState(() {
        _carga = carga;
        _escolhidos = <String>{};
        _fase = _Fase.escolhendo;
      });
    } on EtlUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = e.mensagem;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = 'Erro inesperado durante o envio: $e';
      });
    }
  }

  /// Etapa 2: inicia a carga só com os municípios escolhidos.
  Future<void> _iniciarCarga() async {
    final EtlCarga? carga = _carga;
    if (carga == null || _escolhidos.isEmpty || _ocupado) return;
    setState(() {
      _fase = _Fase.iniciando;
      _erro = null;
    });
    try {
      final EtlCarga iniciada = await EtlService.iniciarCarga(carga, _escolhidos.toList());
      if (!mounted) return;
      Navigator.of(context).pop(_resultado(carga: iniciada));
    } on EtlUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _modoCsv ? _buildCsv() : _buildZip();
  }

  Widget _botaoPrimario({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) =>
      EtlPrimaryButton(
        label: label,
        icon: icon,
        iconSize: 16,
        fontSize: 12,
        gap: 6,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shadowColor: EtlColors.teal600Shadow20,
        onPressed: onPressed,
      );

  /// Modo CSV: o corpo é o painel de pontos; o rodapé segue o estado dele.
  Widget _buildCsv() {
    final bool comResumo = _csv.resumo != null;
    return EtlModalCard(
      onEsc: _fechar,
      cabecalho: EtlModalCabecalho(
        titulo: 'Pontos externos (CSV)',
        icone: Icons.add_location_alt_outlined,
        onFechar: _ocupado ? null : _fechar,
        subtitulo: comResumo
            ? 'Resultado da importação de $_csvNome'
            : 'Escolha a distribuidora e o município, confira a prévia e importe os pontos',
      ),
      conteudo: [
        CsvImportPainel(
          key: ValueKey<int>(_csvChave),
          nomeArquivo: _csvNome!,
          bytes: _csvBytes!,
          controller: _csv,
          distribuidorasService: widget.distribuidorasService,
          onTrocarArquivo: _voltarParaArquivo,
          onImportado: _aoImportarCsv,
        ),
      ],
      rodape: comResumo
          ? [
              EtlOutlineButton(label: 'Fechar', onPressed: _fechar),
              const SizedBox(width: 12),
              _botaoPrimario(
                label: 'Importar outro arquivo',
                icon: Icons.upload_file_outlined,
                onPressed: _voltarParaArquivo,
              ),
            ]
          : [
              EtlOutlineButton(label: 'Cancelar', onPressed: _ocupado ? null : _fechar),
              const SizedBox(width: 12),
              _botaoPrimario(
                label: _csv.enviando
                    ? (_csv.progresso >= 1 ? 'Validando...' : 'Enviando...')
                    : 'Importar pontos',
                icon: Icons.cloud_upload_outlined,
                onPressed: _csv.podeEnviar ? () => _csv.enviar() : null,
              ),
            ],
    );
  }

  /// Área de arrastar (aceita os dois tipos) e o fluxo do .zip, igual ao de
  /// antes do modal único.
  Widget _buildZip() {
    final bool temArquivo = _nome != null;
    final bool naEscolha = _naEscolha;
    final bool podeEnviar = _temArquivo && !_ocupado && !naEscolha;
    final bool podeIniciar = naEscolha && _escolhidos.isNotEmpty && !_ocupado;
    final bool aceitaSoltar = !_ocupado && !naEscolha;

    // O modal inteiro recebe o arquivo solto, não só a área tracejada: com
    // as diretrizes dos dois formatos a área ficou pequena, e soltar fora
    // dela não fazia nada (o desktop_drop cancela a ação do navegador).
    return DropTarget(
      enable: aceitaSoltar,
      onDragEntered: (_) => setState(() => _arrastando = true),
      // Também no "update": se um soltar anterior falhou dentro do
      // desktop_drop, ele não volta ao estado inicial e não avisa a entrada.
      onDragUpdated: (_) {
        if (!_arrastando) setState(() => _arrastando = true);
      },
      onDragExited: (_) => setState(() => _arrastando = false),
      onDragDone: (detalhe) {
        // Na web quem recebe o arquivo é [_aoSoltarNoNavegador].
        if (envioPeloNavegador) return;
        if (detalhe.files.isNotEmpty) _selecionarSolto(detalhe.files.first);
      },
      child: _cardZip(
          temArquivo: temArquivo,
          naEscolha: naEscolha,
          podeEnviar: podeEnviar,
          podeIniciar: podeIniciar),
    );
  }

  Widget _cardZip({
    required bool temArquivo,
    required bool naEscolha,
    required bool podeEnviar,
    required bool podeIniciar,
  }) {
    return EtlModalCard(
      onEsc: _fechar,
      cabecalho: EtlModalCabecalho(
        titulo: temArquivo || naEscolha ? 'Geodatabase (.zip)' : 'Enviar arquivo',
        onFechar: _ocupado ? null : _fechar,
        subtitulo: naEscolha
            ? 'Passo 2 de 2: escolha os municípios a carregar'
            : (temArquivo
                ? 'Passo 1 de 2: envie o .zip; o sistema lê os municípios do arquivo'
                : 'Arraste um .zip com a BDGD ou um .csv de pontos externos: o tipo é reconhecido pelo arquivo'),
      ),
      conteudo: [
        if (!naEscolha) ...[
          EtlCaixaDiretrizes(
            textos: [
              const TextSpan(text: ' envie um '),
              EtlCaixaDiretrizes.codigo('.zip'),
              const TextSpan(
                  text: ' com o File Geodatabase (.gdb) da BDGD: o ETL lê schemas, camadas '
                      'vetoriais e tabelas, e depois você escolhe os municípios a carregar. Ou um '),
              EtlCaixaDiretrizes.codigo('.csv'),
              const TextSpan(text: ' de pontos externos, com colunas separadas por '),
              EtlCaixaDiretrizes.codigo(';'),
              const TextSpan(text: ' e cabeçalho '),
              EtlCaixaDiretrizes.codigo('id;latitude;longitude;papel'),
              const TextSpan(text: ' ('),
              EtlCaixaDiretrizes.codigo('descricao'),
              const TextSpan(text: ' é opcional; colunas em qualquer ordem). O papel é '),
              EtlCaixaDiretrizes.codigo('candidato'),
              const TextSpan(text: ', '),
              EtlCaixaDiretrizes.codigo('ponto_a_cobrir'),
              const TextSpan(text: ' ou '),
              EtlCaixaDiretrizes.codigo('interesse'),
              const TextSpan(
                  text: '; latitude e longitude em graus decimais, com ponto ou vírgula.'),
            ],
            rodape: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                EtlBotaoLink(
                  icone: Icons.download_outlined,
                  label: 'Baixar modelo CSV',
                  onTap: _baixarModelo,
                ),
                if (_avisoModelo != null)
                  Text(_avisoModelo!,
                      style: etlText(11, color: EtlColors.slate500, lineHeight: 16)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          EtlDropZone(
            enabled: !_ocupado,
            onTap: _escolherArquivo,
            onDrop: _selecionarSolto,
            recebeSoltar: false, // quem recebe é o DropTarget do modal
            destacado: _arrastando,
            titulo: 'Arraste o arquivo .zip ou .csv aqui ou clique para selecionar',
            legenda: 'Formatos aceitos: .zip (File Geodatabase) ou .csv (pontos externos)',
          ),
        ],
        if (temArquivo) ...[
          if (!naEscolha) const SizedBox(height: 16),
          EtlCardArquivo(
            nome: _nome!,
            formato: '.zip (.gdb compactado)',
            status: 'Pronto para processamento',
            onSubstituir: _ocupado || naEscolha ? null : _escolherArquivo,
          ),
        ],
        if (naEscolha) ...[
          const SizedBox(height: 16),
          EscolhaMunicipios(
            inspecao: _carga!.inspecao!,
            enabled: !_ocupado,
            onChanged: (s) => setState(() => _escolhidos = s),
          ),
        ],
        if (!naEscolha &&
            (_fase == _Fase.pronto || _fase == _Fase.enviando)) ...[
          const SizedBox(height: 16),
          EtlCardProgresso(
            enviando: _fase == _Fase.enviando,
            progresso: _fase == _Fase.enviando ? _progresso : 1,
            texto: _fase != _Fase.enviando
                ? 'Estrutura validada com sucesso!'
                : (_progresso >= 1
                    ? 'Analisando o arquivo: descompactando e lendo os municípios...'
                    : 'Enviando arquivo...'),
          ),
        ],
        if (_fase == _Fase.erro) ...[
          const SizedBox(height: 16),
          EtlCaixaErro(
            mensagem: _erro ?? 'Falha no envio do arquivo.',
            onTentar: naEscolha
                ? (_escolhidos.isNotEmpty ? _iniciarCarga : null)
                : (_temArquivo ? _enviar : _escolherArquivo),
          ),
        ],
      ],
      rodape: [
        if (naEscolha)
          EtlOutlineButton(
              label: 'Descartar arquivo',
              onPressed: _ocupado ? null : _descartar)
        else
          EtlOutlineButton(
              label: 'Cancelar', onPressed: _ocupado ? null : _fechar),
        const SizedBox(width: 12),
        _botaoPrimario(
          label: naEscolha
              ? (_fase == _Fase.iniciando
                  ? 'Iniciando...'
                  : 'Iniciar carga${_escolhidos.isEmpty ? '' : ' (${_escolhidos.length})'}')
              : (_fase == _Fase.enviando
                  ? (_progresso >= 1 ? 'Analisando...' : 'Enviando...')
                  : (_temArquivo ? 'Enviar e analisar' : 'Enviar')),
          icon: naEscolha ? Icons.play_arrow_rounded : Icons.cloud_upload_outlined,
          onPressed: naEscolha
              ? (podeIniciar ? _iniciarCarga : null)
              : (podeEnviar ? _enviar : null),
        ),
      ],
    );
  }
}
