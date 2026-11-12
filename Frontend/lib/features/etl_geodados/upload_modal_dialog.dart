import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'etl_theme.dart';
import 'models/etl_carga.dart';
import 'services/arquivo_local.dart';
import 'services/etl_service.dart';
import 'widgets/etl_buttons.dart';
import 'widgets/escolha_municipios.dart';
import 'widgets/etl_modal.dart';

enum _Fase { vazio, pronto, enviando, escolhendo, iniciando, erro }

/// Modal "Upload Geodatabase (.zip)".
///
/// Uso: `final EtlCarga? nova = await UploadModalDialog.show(context);`
/// Devolve a carga criada pelo backend, ou `null` se foi cancelado.
///
/// Fluxo em dois passos (#TG-143): envia o .zip, o backend lê a .gdb e
/// devolve os municípios do arquivo; o ADM escolhe e inicia a carga. Com
/// [aguardando], o modal abre direto no passo 2 de uma carga já enviada.
///
/// As peças visuais (cabeçalho, dropzone, cards...) ficam em
/// `widgets/etl_modal.dart`, compartilhadas com o modal de CSV (#TG-90).
class UploadModalDialog extends StatefulWidget {
  const UploadModalDialog({super.key, this.aguardando});

  final EtlCarga? aguardando;

  static Future<EtlCarga?> show(BuildContext context, {EtlCarga? aguardando}) =>
      mostrarModalEtl<EtlCarga>(
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

  bool get _ocupado => _fase == _Fase.enviando || _fase == _Fase.iniciando;

  /// Etapa 2: o arquivo já foi lido pelo backend e falta escolher as cidades.
  bool get _naEscolha => _carga?.inspecao != null;

  @override
  void initState() {
    super.initState();
    if (envioPeloNavegador) prepararArquivosSoltos();
    final EtlCarga? aguardando = widget.aguardando;
    if (aguardando != null) {
      _carga = aguardando;
      _nome = aguardando.nomeArquivo;
      _fase = _Fase.escolhendo;
    }
  }

  /// Na web o arquivo é uma referência do navegador (sem ler os bytes para
  /// a memória); nas demais plataformas, o caminho no disco (#TG-141).
  bool get _temArquivo => _caminho != null || _arquivoNavegador != null;

  /// Fechar na etapa de escolha mantém o upload no histórico como
  /// "Aguardando escolha" (dá para retomar pelo card); "Descartar" apaga.
  void _fechar() {
    if (_ocupado) return;
    Navigator.of(context).pop(_carga);
  }

  Future<void> _descartar() async {
    final EtlCarga? carga = _carga;
    if (carga == null || _ocupado) return;
    setState(() => _fase = _Fase.iniciando);
    try {
      final EtlCarga cancelada = await EtlService.cancelarCarga(carga);
      if (!mounted) return;
      Navigator.of(context).pop(cancelada);
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
        final ArquivoLocal? arquivo = await escolherZipNoNavegador();
        if (arquivo == null || !mounted) return;
        await _selecionarArquivo(nome: arquivo.nome, arquivo: arquivo);
        return;
      }
      final FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
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

  Future<void> _selecionarSolto(DropItem item) async {
    if (_ocupado || _naEscolha) return;
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

  Future<void> _selecionarArquivo({
    required String nome,
    String? caminho,
    ArquivoLocal? arquivo,
  }) async {
    if (_ocupado) return;

    if (!nome.toLowerCase().endsWith('.zip')) {
      setState(() {
        _fase = _Fase.erro;
        _erro = 'O arquivo "$nome" possui formato inválido. '
            'Aceita-se apenas arquivos com extensão .zip contendo o Geodatabase (.gdb).';
      });
      return;
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
        Navigator.of(context).pop(carga);
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
      Navigator.of(context).pop(iniciada);
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
    final bool temArquivo = _nome != null;
    final bool naEscolha = _naEscolha;
    final bool podeEnviar = _temArquivo && !_ocupado && !naEscolha;
    final bool podeIniciar = naEscolha && _escolhidos.isNotEmpty && !_ocupado;

    return EtlModalCard(
      onEsc: _fechar,
      cabecalho: EtlModalCabecalho(
        titulo: 'Upload Geodatabase (.zip)',
        onFechar: _ocupado ? null : _fechar,
        subtitulo: naEscolha
            ? 'Passo 2 de 2: escolha os municípios a carregar'
            : 'Passo 1 de 2: envie o .zip; o sistema lê os municípios do arquivo',
      ),
      conteudo: [
        if (!naEscolha) ...[
          EtlCaixaDiretrizes(textos: [
            const TextSpan(
                text:
                    ' O File Geodatabase (.gdb) deve ser enviado exclusivamente compactado em formato '),
            EtlCaixaDiretrizes.codigo('.zip'),
            const TextSpan(
                text:
                    '. O ETL irá ler schemas, camadas vetoriais e tabelas alfanuméricas.'),
          ]),
          const SizedBox(height: 20),
          EtlDropZone(
            enabled: !_ocupado,
            onTap: _escolherArquivo,
            onDrop: _selecionarSolto,
            titulo: 'Arraste o arquivo .zip aqui ou clique para selecionar',
            legenda: 'Formato exclusivo aceito: .zip (File Geodatabase)',
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
        EtlPrimaryButton(
          label: naEscolha
              ? (_fase == _Fase.iniciando
                  ? 'Iniciando...'
                  : 'Iniciar carga${_escolhidos.isEmpty ? '' : ' (${_escolhidos.length})'}')
              : (_fase == _Fase.enviando
                  ? (_progresso >= 1 ? 'Analisando...' : 'Enviando...')
                  : 'Enviar e analisar'),
          icon: naEscolha ? Icons.play_arrow_rounded : Icons.cloud_upload_outlined,
          iconSize: 16,
          fontSize: 12,
          gap: 6,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shadowColor: EtlColors.teal600Shadow20,
          onPressed: naEscolha
              ? (podeIniciar ? _iniciarCarga : null)
              : (podeEnviar ? _enviar : null),
        ),
      ],
    );
  }
}
