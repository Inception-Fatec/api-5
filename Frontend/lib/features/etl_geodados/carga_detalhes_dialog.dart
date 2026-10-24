import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'etl_theme.dart';
import 'models/etl_carga.dart';
import 'widgets/etl_buttons.dart';

/// Modal "Detalhes da carga" (aberto ao clicar num card da lista).
///
class CargaDetalhesDialog extends StatelessWidget {
  const CargaDetalhesDialog({super.key, required this.carga});

  final EtlCarga carga;

  static Future<bool?> show(BuildContext context, EtlCarga carga) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: EtlColors.overlay,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: CargaDetalhesDialog(carga: carga),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final EtlCarga c = carga;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672 + 32),
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
                      _Cabecalho(carga: c),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _Metrica(rotulo: 'Tamanho do Arquivo', valor: c.tamanhoFormatado)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Metrica(
                                        rotulo: 'Tempo de Processamento',
                                        valor: c.duracao ?? '—',
                                        corValor: EtlColors.teal700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Metrica(
                                        rotulo: 'Tabelas Carregadas',
                                        valor: c.totalCamadas > 0 ? '${c.totalCamadas}' : '—',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Metrica(
                                        rotulo: 'Registros Gravados',
                                        valor: c.camadas.isEmpty ? '—' : EtlCarga.milhar(c.totalGravados),
                                        corValor: EtlColors.slate900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _SecaoCamadas(camadas: c.camadas),
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
                            EtlOutlineButton(label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
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
  const _Cabecalho({required this.carga});

  final EtlCarga carga;

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
            child: const Icon(Icons.dataset_outlined, size: 24, color: EtlColors.teal600),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BotaoFechar(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _BotaoFechar extends StatefulWidget {
  const _BotaoFechar({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BotaoFechar> createState() => _BotaoFecharState();
}

class _BotaoFecharState extends State<_BotaoFechar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
          child: Icon(Icons.close, size: 20, color: _hover ? EtlColors.slate600 : EtlColors.slate400),
        ),
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