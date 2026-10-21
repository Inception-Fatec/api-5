import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'etl_theme.dart';
import 'models/etl_carga.dart';
import 'widgets/etl_buttons.dart';

/// Modal "Detalhes da carga" (aberto ao clicar num card da lista).
///
/// Devolve `true` se o utilizador carregou em "Visualizar no Mapa".
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
                                        rotulo: 'SRID / Projeção',
                                        valor: c.sridCurto ?? '—',
                                        tooltip: c.srid,
                                        tamanhoValor: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Metrica(
                                        rotulo: 'Total de Feições',
                                        valor: c.totalFeicoes ?? '—',
                                        corValor: EtlColors.slate900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const _CaixaTopologia(),
                              const SizedBox(height: 20),
                              _SecaoCamadas(camadas: c.camadas, total: c.totalCamadas),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            EtlOutlineButton(label: 'Fechar', onPressed: () => Navigator.of(context).pop()),
                            EtlPrimaryButton(
                              label: 'Visualizar no Mapa',
                              icon: Icons.map_outlined,
                              iconSize: 16,
                              fontSize: 12,
                              gap: 6,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shadowColor: EtlColors.teal600Shadow20,
                              onPressed: () => Navigator.of(context).pop(true),
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
                        'Executado em ${carga.executadoEm ?? '—'} • Pipeline PostGIS / GeoServer',
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

class _CaixaTopologia extends StatelessWidget {
  const _CaixaTopologia();

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
            child: Icon(Icons.verified_user_outlined, size: 18, color: EtlColors.teal600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: 'Topologia e Integridade Espacial:',
                    style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 19.5),
                  ),
                  const TextSpan(text: ' Todas as geometrias foram validadas no banco PostGIS com índice '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xB3CCFBF1), // teal-100/70
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('GIST', style: etlText(11, color: EtlColors.teal800, lineHeight: 14, mono: true)),
                    ),
                  ),
                  const TextSpan(text: ' e schemas isolados por projeto.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Camadas ───────────────────────────────

class _SecaoCamadas extends StatelessWidget {
  const _SecaoCamadas({required this.camadas, required this.total});

  final List<EtlCamada> camadas;
  final int total;

  static const int _fNome = 5;
  static const int _fTipo = 4;
  static const int _fReg = 2;

  @override
  Widget build(BuildContext context) {
    final int n = camadas.isNotEmpty ? camadas.length : total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, size: 14, color: EtlColors.teal600),
            const SizedBox(width: 6),
            Text(
              'CAMADAS EXTRAÍDAS NO POSTGIS ($n)',
              style: etlText(12,
                  weight: FontWeight.w700, color: EtlColors.slate900, lineHeight: 16, letterSpacing: 0.6),
            ),
            const Spacer(),
            Text('Banco de Destino: ', style: etlText(11, color: EtlColors.slate400, lineHeight: 16.5)),
            Text('tecsys_geodb',
                style: etlText(11, weight: FontWeight.w700, color: EtlColors.slate600, lineHeight: 16.5)),
          ],
        ),
        const SizedBox(height: 10),
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
                    _cel(_fNome, 16, Text('Tabela / Layer PostGIS', style: _cab())),
                    _cel(_fTipo, 12, Text('Tipo de Geometria', style: _cab())),
                    _cel(_fReg, 12, Text('Registros', style: _cab())),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 16),
                      child: SizedBox(
                        width: 76,
                        child: Text('Integridade', textAlign: TextAlign.right, style: _cab()),
                      ),
                    ),
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
                      _cel(_fTipo, 12, Align(alignment: Alignment.centerLeft, child: _ChipGeometria(tipo: camadas[i].tipo))),
                      _cel(
                        _fReg,
                        12,
                        Text(camadas[i].registros,
                            style: etlText(12, weight: FontWeight.w500, color: EtlColors.slate700, lineHeight: 16)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 16),
                        child: SizedBox(
                          width: 76,
                          child: Align(alignment: Alignment.centerRight, child: _ChipIntegridade(valida: camadas[i].valida)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static TextStyle _cab() => etlText(12, weight: FontWeight.w600, color: EtlColors.slate500, lineHeight: 16);

  static Widget _cel(int flex, double padEsq, Widget child) {
    return Expanded(
      flex: flex,
      child: Padding(padding: EdgeInsets.only(left: padEsq), child: child),
    );
  }
}

class _ChipGeometria extends StatelessWidget {
  const _ChipGeometria({required this.tipo});

  final String tipo;

  @override
  Widget build(BuildContext context) {
    IconData icone = Icons.polyline_outlined;
    if (tipo.contains('Point')) icone = Icons.pin_drop_outlined;
    if (tipo.contains('Polygon')) icone = Icons.pentagon_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: EtlColors.slate100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: EtlColors.teal600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(tipo,
                overflow: TextOverflow.ellipsis,
                style: etlText(11, color: EtlColors.slate700, lineHeight: 16.5, mono: true)),
          ),
        ],
      ),
    );
  }
}

class _ChipIntegridade extends StatelessWidget {
  const _ChipIntegridade({required this.valida});

  final bool valida;

  @override
  Widget build(BuildContext context) {
    final Color fundo = valida ? EtlColors.emerald50 : const Color(0xFFFFF1F2);
    final Color borda = valida ? EtlColors.emerald200 : EtlColors.rose200;
    final Color texto = valida ? EtlColors.emerald700 : EtlColors.rose700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fundo,
        border: Border.all(color: borda),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(valida ? Icons.check : Icons.close, size: 12, color: texto),
          const SizedBox(width: 4),
          Text(valida ? 'Válida' : 'Inválida',
              style: etlText(11, weight: FontWeight.w500, color: texto, lineHeight: 16.5)),
        ],
      ),
    );
  }
}
