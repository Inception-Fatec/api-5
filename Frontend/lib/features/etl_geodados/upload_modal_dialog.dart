import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'etl_theme.dart';
import 'models/etl_carga.dart';
import 'services/etl_service.dart';
import 'widgets/etl_buttons.dart';
import 'widgets/seletor_municipio.dart';


enum _Fase { vazio, pronto, enviando, erro }

/// Modal "Upload Geodatabase (.zip)".
///
/// Uso: `final EtlCarga? nova = await UploadModalDialog.show(context);`
/// Devolve a carga criada pelo backend, ou `null` se foi cancelado.
class UploadModalDialog extends StatefulWidget {
  const UploadModalDialog({super.key});

  static Future<EtlCarga?> show(BuildContext context) {
    return showGeneralDialog<EtlCarga>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Fechar',
      barrierColor: EtlColors.overlay,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Stack(
          children: [
            // backdrop-blur-sm (4px) por cima do overlay slate-900/60.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: const UploadModalDialog(),
              ),
            ),
          ],
        );
      },
      // O fade é aplicado só ao cartão (BackdropFilter não deve ficar dentro de Opacity).
      transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
    );
  }

  @override
  State<UploadModalDialog> createState() => _UploadModalDialogState();
}

class _UploadModalDialogState extends State<UploadModalDialog> {
  _Fase _fase = _Fase.vazio;
  String? _nome;
  String? _caminho;
  double _progresso = 0;
  String? _erro;
  List<Municipio> _municipios = <Municipio>[];

  bool get _ocupado => _fase == _Fase.enviando;

  void _fechar() {
    if (_ocupado) return;
    Navigator.of(context).pop();
  }

  Future<void> _escolherArquivo() async {
    if (_ocupado) return;
    try {
      final FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        allowMultiple: false,
      );
      if (resultado == null || resultado.files.isEmpty) return;
      final String? caminho = resultado.files.first.path;
      if (caminho == null) return;
      await _selecionar(caminho);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.erro;
        _erro = 'Não foi possível abrir o seletor de arquivos: $e';
      });
    }
  }

  Future<void> _selecionar(String caminho) async {
    if (_ocupado) return;
    final String nome = caminho.split(Platform.pathSeparator).last;

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
      problema = await EtlService.validarEstruturaZip(caminho);
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
      _progresso = 1;
      _erro = null;
      _fase = _Fase.pronto;
    });
  }

  Future<void> _enviar() async {
    final String? caminho = _caminho;
    final String? nome = _nome;
    final List<Municipio> municipios = _municipios;
    if (caminho == null || nome == null || municipios.isEmpty || _ocupado) return;

    setState(() {
      _fase = _Fase.enviando;
      _progresso = 0;
      _erro = null;
    });

    try {
      final EtlCarga carga = await EtlService.enviarZip(
        caminho: caminho,
        nomeArquivo: nome,
        municipios: municipios.map((m) => m.codigo).toList(),
        onProgress: (p) {
          if (mounted) setState(() => _progresso = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(carga);
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

  @override
  Widget build(BuildContext context) {
    final bool temArquivo = _nome != null;
    final bool podeEnviar = _caminho != null && _municipios.isNotEmpty && !_ocupado;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _fechar},
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 576 + 32),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kEtlModalRadius),
                  border: Border.all(color: EtlColors.slate100),
                  boxShadow: const [
                    BoxShadow(color: EtlColors.black25, blurRadius: 50, spreadRadius: -12, offset: Offset(0, 25)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kEtlModalRadius - 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Cabecalho(onFechar: _ocupado ? null : _fechar),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _CaixaDiretrizes(),
                              const SizedBox(height: 20),
                              _DropZone(
                                enabled: !_ocupado,
                                onTap: _escolherArquivo,
                                onPath: _selecionar,
                              ),
                              if (temArquivo) ...[
                                const SizedBox(height: 16),
                                _CardArquivo(
                                  nome: _nome!,
                                  onSubstituir: _ocupado ? null : _escolherArquivo,
                                ),
                              ],
                              const SizedBox(height: 16),
                              SeletorMunicipio(
                                key: const ValueKey('seletor-municipio'),
                                enabled: !_ocupado,
                                onChanged: (lista) => setState(() => _municipios = lista),
                              ),
                              if (_fase == _Fase.pronto || _fase == _Fase.enviando) ...[
                                const SizedBox(height: 16),
                                _CardProgresso(
                                  enviando: _fase == _Fase.enviando,
                                  progresso: _fase == _Fase.enviando ? _progresso : 1,
                                ),
                              ],
                              if (_fase == _Fase.erro) ...[
                                const SizedBox(height: 16),
                                _CaixaErro(
                                  mensagem: _erro ?? 'Falha no envio do arquivo.',
                                  onTentar: _caminho != null ? _enviar : _escolherArquivo,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: EtlColors.slate50,
                          border: Border(top: BorderSide(color: EtlColors.slate100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            EtlOutlineButton(label: 'Cancelar', onPressed: _ocupado ? null : _fechar),
                            const SizedBox(width: 12),
                            EtlPrimaryButton(
                              label: _ocupado ? 'Enviando...' : 'Iniciar Upload',
                              icon: Icons.cloud_upload_outlined,
                              iconSize: 16,
                              fontSize: 12,
                              gap: 6,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shadowColor: EtlColors.teal600Shadow20,
                              onPressed: podeEnviar ? _enviar : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Cabeçalho ───────────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.onFechar});

  final VoidCallback? onFechar;

  @override
  Widget build(BuildContext context) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EtlColors.teal50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cloud_upload_outlined, size: 24, color: EtlColors.teal600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Geodatabase (.zip)',
                  style: etlText(18,
                      weight: FontWeight.w700,
                      color: EtlColors.slate900,
                      lineHeight: 28,
                      letterSpacing: -0.45),
                ),
                const SizedBox(height: 2),
                Text(
                  'Envie o arquivo espelhado para extração, transformação e carga (ETL)',
                  style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                ),
              ],
            ),
          ),
          _BotaoIcone(icone: Icons.close, onTap: onFechar),
        ],
      ),
    );
  }
}

class _BotaoIcone extends StatefulWidget {
  const _BotaoIcone({required this.icone, required this.onTap});

  final IconData icone;
  final VoidCallback? onTap;

  @override
  State<_BotaoIcone> createState() => _BotaoIconeState();
}

class _BotaoIconeState extends State<_BotaoIcone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hover ? EtlColors.slate100 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icone,
            size: 20,
            color: _hover ? EtlColors.slate600 : EtlColors.slate400,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Caixa de diretrizes ─────────────────────────────

class _CaixaDiretrizes extends StatelessWidget {
  const _CaixaDiretrizes();

  @override
  Widget build(BuildContext context) {
    final TextStyle base = etlText(12, color: EtlColors.slate600, lineHeight: 19.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EtlColors.teal50a60,
        border: Border.all(color: EtlColors.teal100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 18, color: EtlColors.teal600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: 'Diretrizes do Arquivo:',
                    style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 19.5),
                  ),
                  const TextSpan(text: ' O File Geodatabase (.gdb) deve ser enviado exclusivamente compactado em formato '),
                  TextSpan(
                    text: '.zip',
                    style: etlText(12, weight: FontWeight.w600, color: EtlColors.teal800, lineHeight: 19.5, mono: true),
                  ),
                  const TextSpan(text: '. O ETL irá ler schemas, camadas vetoriais e tabelas alfanuméricas.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Dropzone ────────────────────────────────

class _DropZone extends StatefulWidget {
  const _DropZone({required this.enabled, required this.onTap, required this.onPath});

  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<String> onPath;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;
  bool _arrastando = false;

  @override
  Widget build(BuildContext context) {
    final bool ativo = widget.enabled && (_hover || _arrastando);

    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _arrastando = true),
      onDragExited: (_) => setState(() => _arrastando = false),
      onDragDone: (detalhe) {
        setState(() => _arrastando = false);
        if (detalhe.files.isNotEmpty) widget.onPath(detalhe.files.first.path);
      },
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(
              color: ativo ? EtlColors.teal500 : EtlColors.slate300,
              radius: 16,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.all(22), // p-5 (20) + border-2
              decoration: BoxDecoration(
                color: ativo ? EtlColors.teal50a20 : EtlColors.slate50a50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ativo ? EtlColors.teal200 : EtlColors.slate200),
                      boxShadow: const [
                        BoxShadow(color: EtlColors.black5, blurRadius: 1, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Icon(Icons.upload, size: 24, color: EtlColors.teal600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arraste o arquivo .zip aqui ou clique para selecionar',
                    textAlign: TextAlign.center,
                    style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Formato exclusivo aceito: .zip (File Geodatabase)',
                    textAlign: TextAlign.center,
                    style: etlText(11, color: EtlColors.slate400, lineHeight: 16.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);

    final Path path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distancia = 0;
      while (distancia < metric.length) {
        final double fim = math.min(distancia + dash, metric.length);
        canvas.drawPath(metric.extractPath(distancia, fim), paint);
        distancia += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}

// ───────────────────────────── Card do ficheiro ─────────────────────────────

class _CardArquivo extends StatelessWidget {
  const _CardArquivo({required this.nome, required this.onSubstituir});

  final String nome;
  final VoidCallback? onSubstituir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EtlColors.slate50a60,
        border: Border.all(color: EtlColors.slate200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: EtlColors.teal600,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: EtlColors.teal600Shadow20, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: const Icon(Icons.folder_zip_outlined, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: etlText(14, weight: FontWeight.w600, color: EtlColors.slate900, lineHeight: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EtlColors.emerald100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Válido',
                        style: etlText(10, weight: FontWeight.w600, color: EtlColors.emerald800, lineHeight: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '.zip (.gdb compactado)',
                      style: etlText(12, color: EtlColors.teal700, lineHeight: 16, mono: true),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: etlText(12, color: EtlColors.slate500, lineHeight: 16)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pronto para processamento',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BotaoIcone(icone: Icons.sync, onTap: onSubstituir),
        ],
      ),
    );
  }
}

// ───────────────────────────── Indicador de progresso ─────────────────────────────

class _CardProgresso extends StatelessWidget {
  const _CardProgresso({required this.enviando, required this.progresso});

  final bool enviando;
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final double p = progresso.clamp(0.0, 1.0).toDouble();
    final int pct = (p * 100).round();
    final String texto = !enviando
        ? 'Estrutura validada com sucesso!'
        : (p >= 1 ? 'Processando no servidor...' : 'Enviando arquivo...');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EtlColors.slate50,
        border: Border.all(color: EtlColors.slate200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (enviando)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(EtlColors.teal600),
                  ),
                )
              else
                const Icon(Icons.check_circle_outline, size: 16, color: EtlColors.teal600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16),
                ),
              ),
              Text(
                '$pct%',
                style: etlText(12, weight: FontWeight.w700, color: EtlColors.teal700, lineHeight: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: EtlColors.slate200,
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: p,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: EtlColors.teal600,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Erro ────────────────────────────────

class _CaixaErro extends StatelessWidget {
  const _CaixaErro({required this.mensagem, required this.onTentar});

  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EtlColors.rose50a70,
        border: Border.all(color: EtlColors.rose200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EtlColors.rose100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.error_outline, size: 24, color: EtlColors.rose600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Falha no Envio do Arquivo',
                  style: etlText(14, weight: FontWeight.w700, color: EtlColors.rose900, lineHeight: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  mensagem,
                  style: etlText(12, color: EtlColors.rose700, lineHeight: 19.5),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onTentar,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: EtlColors.rose600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Tentar Novamente',
                            style: etlText(12, weight: FontWeight.w600, color: Colors.white, lineHeight: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}