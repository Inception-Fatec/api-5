import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../etl_theme.dart';

/// Peças visuais compartilhadas pelos modais da tela de ETL: o upload do
/// .zip (`UploadModalDialog`) e a importação de pontos por CSV
/// (`CsvImportDialog`, #TG-90). Extraídas do modal do .zip para os dois
/// terem exatamente o mesmo visual; os textos que eram fixos de .zip
/// viraram parâmetros.

/// Abre [modal] com o overlay escuro + blur usado nos modais do ETL.
/// [fecharAoClicarFora]: clicar no fundo fecha (detalhes de uma carga); nos
/// modais de envio fica desligado para não perder o arquivo escolhido.
Future<T?> mostrarModalEtl<T>(BuildContext context, Widget modal,
    {bool fecharAoClicarFora = false}) {
  return showGeneralDialog<T>(
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
              child: fecharAoClicarFora
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const SizedBox.expand(),
                    )
                  : const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          // showGeneralDialog não desvia do teclado: o cartão sobe e
          // encolhe (o conteúdo dele já rola).
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            curve: Curves.decelerate,
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Center(
              child: FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: modal,
              ),
            ),
          ),
        ],
      );
    },
    // O fade é aplicado só ao cartão (BackdropFilter não deve ficar dentro de Opacity).
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

// ─────────────────────────────── Cartão do modal ───────────────────────────────

/// Cartão branco do modal: cabeçalho fixo, corpo rolável e rodapé com os
/// botões. Esc chama [onEsc].
class EtlModalCard extends StatelessWidget {
  const EtlModalCard({
    super.key,
    required this.onEsc,
    required this.cabecalho,
    required this.conteudo,
    required this.rodape,
    this.larguraMaxima = 576,
  });

  final VoidCallback onEsc;
  final Widget cabecalho;
  final List<Widget> conteudo;
  final List<Widget> rodape;

  /// Largura do cartão (sem a margem de 16 de cada lado).
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onEsc},
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraMaxima + 32),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kEtlModalRadius),
                  border: Border.all(color: EtlColors.slate100),
                  boxShadow: const [
                    BoxShadow(
                        color: EtlColors.black25,
                        blurRadius: 50,
                        spreadRadius: -12,
                        offset: Offset(0, 25)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kEtlModalRadius - 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cabecalho,
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: conteudo,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: EtlColors.slate50,
                          border: Border(
                              top: BorderSide(color: EtlColors.slate100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: rodape,
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

class EtlModalCabecalho extends StatelessWidget {
  const EtlModalCabecalho({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.onFechar,
    this.icone = Icons.cloud_upload_outlined,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
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
            child: Icon(icone, size: 24, color: EtlColors.teal600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: etlText(18,
                      weight: FontWeight.w700,
                      color: EtlColors.slate900,
                      lineHeight: 28,
                      letterSpacing: -0.45),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
                ),
              ],
            ),
          ),
          EtlBotaoIcone(icone: Icons.close, onTap: onFechar),
        ],
      ),
    );
  }
}

class EtlBotaoIcone extends StatefulWidget {
  const EtlBotaoIcone(
      {super.key, required this.icone, required this.onTap, this.tooltip});

  final IconData icone;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<EtlBotaoIcone> createState() => _EtlBotaoIconeState();
}

class _EtlBotaoIconeState extends State<EtlBotaoIcone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Widget botao = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
    final String? dica = widget.tooltip;
    return dica == null ? botao : Tooltip(message: dica, child: botao);
  }
}

// ───────────────────────────── Caixa de diretrizes ─────────────────────────────

/// Caixa azul-esverdeada "Diretrizes do Arquivo: ..." com o texto em
/// [textos] (use [codigo] para os trechos em fonte mono) e, opcionalmente,
/// um [rodape] (ex.: botão "Baixar modelo").
class EtlCaixaDiretrizes extends StatelessWidget {
  const EtlCaixaDiretrizes({super.key, required this.textos, this.rodape});

  final List<InlineSpan> textos;
  final Widget? rodape;

  /// Trecho em fonte mono destacado (ex.: `.zip`, `;`).
  static TextSpan codigo(String texto) => TextSpan(
        text: texto,
        style: etlText(12,
            weight: FontWeight.w600,
            color: EtlColors.teal800,
            lineHeight: 19.5,
            mono: true),
      );

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        etlText(12, color: EtlColors.slate600, lineHeight: 19.5);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: base,
                    children: [
                      TextSpan(
                        text: 'Diretrizes do Arquivo:',
                        style: etlText(12,
                            weight: FontWeight.w600,
                            color: EtlColors.slate800,
                            lineHeight: 19.5),
                      ),
                      ...textos,
                    ],
                  ),
                ),
                if (rodape != null) ...[
                  const SizedBox(height: 8),
                  rodape!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Dropzone ────────────────────────────────

/// Área tracejada "arraste ou clique para selecionar".
class EtlDropZone extends StatefulWidget {
  const EtlDropZone({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.onDrop,
    required this.titulo,
    required this.legenda,
    this.recebeSoltar = true,
    this.destacado = false,
  });

  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<DropItem> onDrop;
  final String titulo;
  final String legenda;

  /// `false` quando quem recebe o arquivo solto é um DropTarget maior em
  /// volta (ex.: o modal inteiro, #TG-90); dois alvos receberiam o mesmo
  /// arquivo duas vezes.
  final bool recebeSoltar;

  /// Destaque vindo de fora (arquivo sendo arrastado sobre o modal).
  final bool destacado;

  @override
  State<EtlDropZone> createState() => _EtlDropZoneState();
}

class _EtlDropZoneState extends State<EtlDropZone> {
  bool _hover = false;
  bool _arrastando = false;

  @override
  Widget build(BuildContext context) {
    final bool ativo =
        widget.enabled && (_hover || _arrastando || widget.destacado);

    return DropTarget(
      enable: widget.enabled && widget.recebeSoltar,
      onDragEntered: (_) => setState(() => _arrastando = true),
      onDragExited: (_) => setState(() => _arrastando = false),
      onDragDone: (detalhe) {
        setState(() => _arrastando = false);
        if (detalhe.files.isNotEmpty) widget.onDrop(detalhe.files.first);
      },
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: CustomPaint(
            foregroundPainter: EtlDashedBorderPainter(
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
                      border: Border.all(
                          color:
                              ativo ? EtlColors.teal200 : EtlColors.slate200),
                      boxShadow: const [
                        BoxShadow(
                            color: EtlColors.black5,
                            blurRadius: 1,
                            offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Icon(Icons.upload,
                        size: 24, color: EtlColors.teal600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.titulo,
                    textAlign: TextAlign.center,
                    style: etlText(12,
                        weight: FontWeight.w600,
                        color: EtlColors.slate800,
                        lineHeight: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.legenda,
                    textAlign: TextAlign.center,
                    style: etlText(11,
                        color: EtlColors.slate400, lineHeight: 16.5),
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

class EtlDashedBorderPainter extends CustomPainter {
  const EtlDashedBorderPainter({
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
  bool shouldRepaint(covariant EtlDashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

// ───────────────────────────── Card do arquivo ─────────────────────────────

/// Card do arquivo escolhido. [valido] troca o selo "Válido" por um aviso.
class EtlCardArquivo extends StatelessWidget {
  const EtlCardArquivo({
    super.key,
    required this.nome,
    required this.formato,
    required this.status,
    required this.onSubstituir,
    this.icone = Icons.folder_zip_outlined,
    this.valido = true,
  });

  final String nome;
  final String formato;
  final String status;
  final IconData icone;
  final bool valido;
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
                BoxShadow(
                    color: EtlColors.teal600Shadow20,
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
            ),
            child: Icon(icone, size: 24, color: Colors.white),
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
                        style: etlText(14,
                            weight: FontWeight.w600,
                            color: EtlColors.slate900,
                            lineHeight: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: valido ? EtlColors.emerald100 : EtlColors.amber100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        valido ? 'Válido' : 'Verificar',
                        style: etlText(10,
                            weight: FontWeight.w600,
                            color: valido
                                ? EtlColors.emerald800
                                : EtlColors.amber800,
                            lineHeight: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        formato,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: etlText(12,
                            color: EtlColors.teal700, lineHeight: 16, mono: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•',
                        style: etlText(12,
                            color: EtlColors.slate500, lineHeight: 16)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: etlText(12,
                            color: EtlColors.slate500, lineHeight: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EtlBotaoIcone(icone: Icons.sync, onTap: onSubstituir),
        ],
      ),
    );
  }
}

// ───────────────────────────── Indicador de progresso ─────────────────────────────

class EtlCardProgresso extends StatelessWidget {
  const EtlCardProgresso({
    super.key,
    required this.enviando,
    required this.progresso,
    required this.texto,
  });

  final bool enviando;
  final double progresso;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final double p = progresso.clamp(0.0, 1.0).toDouble();
    final int pct = (p * 100).round();

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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(EtlColors.teal600),
                  ),
                )
              else
                const Icon(Icons.check_circle_outline,
                    size: 16, color: EtlColors.teal600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: etlText(12,
                      weight: FontWeight.w600,
                      color: EtlColors.slate700,
                      lineHeight: 16),
                ),
              ),
              Text(
                '$pct%',
                style: etlText(12,
                    weight: FontWeight.w700,
                    color: EtlColors.teal700,
                    lineHeight: 16),
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

class EtlCaixaErro extends StatelessWidget {
  const EtlCaixaErro({
    super.key,
    required this.mensagem,
    required this.onTentar,
    this.titulo = 'Falha no Envio do Arquivo',
    this.rotuloAcao = 'Tentar Novamente',
  });

  final String titulo;
  final String mensagem;
  final String rotuloAcao;
  final VoidCallback? onTentar;

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
            child: const Icon(Icons.error_outline,
                size: 24, color: EtlColors.rose600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: etlText(14,
                      weight: FontWeight.w700,
                      color: EtlColors.rose900,
                      lineHeight: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  mensagem,
                  style:
                      etlText(12, color: EtlColors.rose700, lineHeight: 19.5),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onTentar,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: EtlColors.rose600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            rotuloAcao,
                            style: etlText(12,
                                weight: FontWeight.w600,
                                color: Colors.white,
                                lineHeight: 16),
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

// ──────────────────────────────── Link ────────────────────────────────

/// Botão discreto com ícone, em verde (ex.: "Baixar modelo CSV").
class EtlBotaoLink extends StatelessWidget {
  const EtlBotaoLink(
      {super.key, required this.icone, required this.label, required this.onTap});

  final IconData icone;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: EtlColors.teal700,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icone, size: 16),
      label: Text(label,
          style: etlText(12,
              weight: FontWeight.w600, color: EtlColors.teal700, lineHeight: 16)),
    );
  }
}
