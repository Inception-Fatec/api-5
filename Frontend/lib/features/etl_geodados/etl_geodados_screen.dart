import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'upload_modal_dialog.dart';

// ============================================================================
// MODELO
// ============================================================================

enum EtlCargaStatus { concluido, processando, falha }

class EtlLayer {
  const EtlLayer({
    required this.name,
    required this.type,
    required this.records,
    this.valid = true,
  });

  final String name;
  final String type;
  final String records;
  final bool valid;
}

class EtlCarga {
  const EtlCarga({
    required this.id,
    required this.fileName,
    required this.sizeLabel,
    required this.engine,
    required this.status,
    required this.timestamp,
    this.duration,
    this.srid,
    this.sridShort,
    this.featuresCount,
    this.layers = const [],
  });

  final String id;
  final String fileName;
  final String sizeLabel;
  final String engine;
  final EtlCargaStatus status;
  final String timestamp;
  final String? duration;
  final String? srid;
  final String? sridShort;
  final String? featuresCount;
  final List<EtlLayer> layers;

  String get subtitle {
    final tail = layers.isEmpty
        ? (status == EtlCargaStatus.processando
            ? 'Processamento iniciado'
            : 'Sem camadas')
        : '${layers.length} Camadas PostGIS';
    return '$sizeLabel • $engine • $tail';
  }
}

/// Dados de demonstração (iguais ao protótipo). Substitua pela listagem real
/// do backend via [EtlGeodadosScreen.initialCargas].
const List<EtlCarga> kEtlDemoCargas = [
  EtlCarga(
    id: 'carga-3',
    fileName: 'dados_geograficos_rede.zip',
    sizeLabel: '36.2 MB',
    engine: 'Geodatabase Esri v10.8',
    status: EtlCargaStatus.concluido,
    timestamp: '24/10/2024 às 15:05',
    duration: '29 segundos',
    srid: 'SIRGAS 2000 (EPSG:4674)',
    sridShort: 'EPSG:4674',
    featuresCount: '54.120',
    layers: [
      EtlLayer(
        name: 'geo_limites_operacionais',
        type: 'Polygon',
        records: '12.800',
      ),
      EtlLayer(name: 'geo_ativos_campo', type: 'Point', records: '41.320'),
    ],
  ),
  EtlCarga(
    id: 'carga-1',
    fileName: 'rede_distribuicao_sp_sul.zip',
    sizeLabel: '42.8 MB',
    engine: 'Geodatabase Esri v10.8',
    status: EtlCargaStatus.concluido,
    timestamp: '24/10/2024 às 14:32',
    duration: '42 segundos',
    srid: 'SIRGAS 2000 (EPSG:4674)',
    sridShort: 'EPSG:4674',
    featuresCount: '128.450',
    layers: [
      EtlLayer(
        name: 'geo_redes_alta_tensao',
        type: 'MultiLineString',
        records: '45.120',
      ),
      EtlLayer(
        name: 'geo_postes_equipamentos',
        type: 'Point',
        records: '78.230',
      ),
      EtlLayer(
        name: 'geo_subestacoes_poligonos',
        type: 'Polygon',
        records: '5.100',
      ),
    ],
  ),
  EtlCarga(
    id: 'carga-2',
    fileName: 'sensores_telemetria_rj.zip',
    sizeLabel: '18.4 MB',
    engine: 'Geodatabase Esri v10.8',
    status: EtlCargaStatus.concluido,
    timestamp: '24/10/2024 às 11:15',
    duration: '18 segundos',
    srid: 'SIRGAS 2000 (EPSG:4674)',
    sridShort: 'EPSG:4674',
    featuresCount: '34.820',
    layers: [
      EtlLayer(name: 'geo_estacoes_sensores', type: 'Point', records: '32.400'),
      EtlLayer(
        name: 'geo_bacias_hidrograficas',
        type: 'Polygon',
        records: '2.420',
      ),
    ],
  ),
];

// ============================================================================
// TELA
// ============================================================================

class EtlGeodadosScreen extends StatefulWidget {
  const EtlGeodadosScreen({
    super.key,
    this.initialCargas,
    this.showAppChrome = true,
    this.onViewOnMap,
  });

  /// Lista inicial de cargas. Se nula, usa [kEtlDemoCargas].
  final List<EtlCarga>? initialCargas;

  /// `true` desenha a barra superior e o rodapé Tecsys da própria tela.
  /// Use `false` se o shell do app já fornece esses elementos.
  final bool showAppChrome;

  /// Chamado por "Visualizar no Mapa" no modal de detalhes.
  final void Function(EtlCarga carga)? onViewOnMap;

  @override
  State<EtlGeodadosScreen> createState() => _EtlGeodadosScreenState();
}

class _EtlGeodadosScreenState extends State<EtlGeodadosScreen> {
  late final List<EtlCarga> _cargas;
  String _updatedLabel = 'Atualizado há poucos minutos';

  @override
  void initState() {
    super.initState();
    _cargas = List<EtlCarga>.of(widget.initialCargas ?? kEtlDemoCargas);
  }

  // ------------------------------------------------------------------ ações

  Future<void> _openUploadModal() async {
    final result = await showUploadModalDialog(context);
    if (result == null || !mounted) return;

    setState(() {
      _cargas.insert(
        0,
        EtlCarga(
          id: 'carga-${DateTime.now().millisecondsSinceEpoch}',
          fileName: result.fileName,
          sizeLabel: formatFileSize(result.sizeBytes),
          engine: 'Geodatabase Esri',
          status: EtlCargaStatus.processando,
          timestamp: _formatNow(),
        ),
      );
      _updatedLabel = 'Atualizado agora';
    });
    _showToast(
      'Arquivo ${result.fileName} enviado com sucesso! '
      'O processamento foi iniciado.',
    );
  }

  Future<void> _openDetails(EtlCarga carga) {
    return showDialog<void>(
      context: context,
      barrierColor: EtlPalette.barrier,
      builder: (dialogContext) => _CargaDetailsDialog(
        carga: carga,
        onViewOnMap: () {
          Navigator.of(dialogContext).pop();
          final callback = widget.onViewOnMap;
          if (callback != null) {
            callback(carga);
          } else {
            _showToast(
              'Carregando camadas no visualizador de mapa...',
              icon: Icons.map_outlined,
            );
          }
        },
      ),
    );
  }

  void _showToast(String message, {IconData icon = Icons.check_circle_outline}) {
    final messenger = ScaffoldMessenger.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EtlPalette.slate900,
        elevation: 8,
        duration: const Duration(milliseconds: 3500),
        margin: EdgeInsets.only(
          left: math.max(16, screenWidth - 480),
          right: 24,
          bottom: 24,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(icon, size: 18, color: EtlPalette.teal400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: EtlText.sans(12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year} às '
        '${two(now.hour)}:${two(now.minute)}';
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EtlPalette.slate50,
      body: Column(
        children: [
          if (widget.showAppChrome) const _TecsysTopBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final hPad = w >= 1024 ? 32.0 : (w >= 640 ? 24.0 : 16.0);
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad,
                          vertical: 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PageHeader(
                              compact: w < 720,
                              onUpload: _openUploadModal,
                            ),
                            const SizedBox(height: 24),
                            _CargasCard(
                              cargas: _cargas,
                              updatedLabel: _updatedLabel,
                              compact: w < 720,
                              onOpen: _openDetails,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (widget.showAppChrome) const _TecsysFooter(),
        ],
      ),
    );
  }
}

// ============================================================================
// BARRA SUPERIOR / RODAPÉ
// ============================================================================

class _TecsysTopBar extends StatelessWidget {
  const _TecsysTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: EtlPalette.slate200)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final hPad = w >= 1024 ? 32.0 : (w >= 640 ? 24.0 : 16.0);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    const _Logo(),
                    if (w >= 768) ...[
                      const SizedBox(width: 32),
                      const _NavItem(label: 'Projetos'),
                      const SizedBox(width: 4),
                      const _NavItem(label: 'Mapa', icon: Icons.map_outlined),
                      const SizedBox(width: 4),
                      const _NavItem(label: 'Usuários'),
                      const SizedBox(width: 4),
                      const _NavItem(
                        label: 'ETL & Geodados',
                        icon: Icons.storage_outlined,
                        active: true,
                      ),
                      const SizedBox(width: 4),
                      const _NavItem(label: 'Configurações'),
                    ],
                    const Spacer(),
                    if (w >= 640) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EtlPalette.slate100,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: EtlPalette.slate200),
                        ),
                        child: Text(
                          'Ambiente: Produção',
                          style: EtlText.sans(
                            12,
                            weight: FontWeight.w500,
                            color: EtlPalette.slate500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: EtlPalette.slate200,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'AD',
                        style: EtlText.sans(
                          12,
                          weight: FontWeight.w600,
                          color: EtlPalette.slate700,
                        ),
                      ),
                    ),
                    if (w >= 1024) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Admin Tecsys',
                        style: EtlText.sans(
                          12,
                          weight: FontWeight.w500,
                          color: EtlPalette.slate700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EtlPalette.teal600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            'T',
            style: EtlText.sans(18, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Tecsys',
          style: EtlText.sans(
            18,
            weight: FontWeight.w700,
            color: EtlPalette.slate900,
            letterSpacing: -0.45,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.label, this.icon, this.active = false});

  final String label;
  final IconData? icon;
  final bool active;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color = active
        ? EtlPalette.teal700
        : (_hover ? EtlPalette.slate900 : EtlPalette.slate600);
    final bg = active
        ? EtlPalette.teal50
        : (_hover ? EtlPalette.slate100 : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: EtlText.sans(
                14,
                weight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TecsysFooter extends StatelessWidget {
  const _TecsysFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: EtlPalette.slate200)),
      ),
      child: Text(
        'Tecsys B2B Platform • Gestão e Processamento Espacial',
        textAlign: TextAlign.center,
        style: EtlText.sans(12, color: EtlPalette.slate400),
      ),
    );
  }
}

// ============================================================================
// CABEÇALHO DA PÁGINA
// ============================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.compact, required this.onUpload});

  final bool compact;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: EtlPalette.teal100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'MÓDULO GEO',
            style: EtlText.sans(
              12,
              weight: FontWeight.w600,
              color: EtlPalette.teal800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Execuções de ETL e Cargas Espaciais',
          style: EtlText.sans(
            24,
            weight: FontWeight.w700,
            color: EtlPalette.slate900,
            letterSpacing: -0.6,
            height: 1.33,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Carregue arquivos compactados (.zip) para processamento '
          'geoespacial, validação topológica e persistência.',
          style: EtlText.sans(14, color: EtlPalette.slate500, height: 1.43),
        ),
      ],
    );

    final button = EtlPrimaryButton(
      label: 'Novo Upload (.zip)',
      icon: Icons.upload_file_outlined,
      onPressed: onUpload,
      fontSize: 14,
      iconSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EtlPalette.slate200)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [texts, const SizedBox(height: 16), button],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: texts),
                const SizedBox(width: 16),
                button,
              ],
            ),
    );
  }
}

// ============================================================================
// CARD DE CARGAS
// ============================================================================

class _CargasCard extends StatelessWidget {
  const _CargasCard({
    required this.cargas,
    required this.updatedLabel,
    required this.compact,
    required this.onOpen,
  });

  final List<EtlCarga> cargas;
  final String updatedLabel;
  final bool compact;
  final void Function(EtlCarga carga) onOpen;

  @override
  Widget build(BuildContext context) {
    final count = cargas.length;
    final hint = EtlText.sans(11, color: EtlPalette.slate400);
    final meta = EtlText.sans(12, weight: FontWeight.w500, color: EtlPalette.slate500);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da lista
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EtlPalette.slate50,
              border: Border(bottom: BorderSide(color: EtlPalette.slate200)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 16, color: EtlPalette.slate400),
                    const SizedBox(width: 8),
                    Text(
                      'Últimas Cargas (.zip)',
                      style: EtlText.sans(
                        12,
                        weight: FontWeight.w600,
                        color: EtlPalette.slate700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCCE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count ${count == 1 ? 'item' : 'itens'}',
                        style: EtlText.sans(
                          11,
                          weight: FontWeight.w700,
                          color: EtlPalette.slate600,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: EtlPalette.slate400,
                    ),
                    const SizedBox(width: 4),
                    Text('Clique em um card para abrir detalhes', style: hint),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      Text('•', style: meta),
                      const SizedBox(width: 12),
                    ],
                    if (!compact) Text(updatedLabel, style: meta),
                  ],
                ),
              ],
            ),
          ),
          // Linhas
          if (cargas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhuma carga realizada ainda. Use "Novo Upload (.zip)" '
                  'para começar.',
                  style: EtlText.sans(13, color: EtlPalette.slate400),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final carga in cargas)
                    _CargaTile(
                      key: ValueKey(carga.id),
                      carga: carga,
                      compact: compact,
                      onTap: () => onOpen(carga),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CargaTile extends StatefulWidget {
  const _CargaTile({
    super.key,
    required this.carga,
    required this.compact,
    required this.onTap,
  });

  final EtlCarga carga;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_CargaTile> createState() => _CargaTileState();
}

class _CargaTileState extends State<_CargaTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final carga = widget.carga;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x4DF0FDFA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? EtlPalette.teal500 : Colors.transparent,
            ),
            boxShadow: _hover
                ? const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                      spreadRadius: -1,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _hover
                            ? EtlPalette.teal600
                            : EtlPalette.teal50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.folder_zip_outlined,
                        size: 22,
                        color: _hover ? Colors.white : EtlPalette.teal700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            carga.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EtlText.mono(
                              14,
                              weight: FontWeight.w500,
                              color: _hover
                                  ? EtlPalette.teal700
                                  : EtlPalette.slate800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            carga.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EtlText.sans(12, color: EtlPalette.slate400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _StatusBadge(status: carga.status),
              if (!widget.compact) ...[
                const SizedBox(width: 20),
                Text(
                  'Detalhes',
                  style: EtlText.sans(
                    12,
                    weight: FontWeight.w600,
                    color: _hover ? EtlPalette.teal600 : EtlPalette.slate400,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: Offset(_hover ? 0.2 : 0, 0),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _hover ? EtlPalette.teal600 : EtlPalette.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.large = false});

  final EtlCargaStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    final Color dot;
    final String label;

    switch (status) {
      case EtlCargaStatus.concluido:
        bg = EtlPalette.emerald50;
        fg = EtlPalette.emerald700;
        border = EtlPalette.emerald200;
        dot = EtlPalette.emerald500;
        label = 'Concluído';
        break;
      case EtlCargaStatus.processando:
        bg = EtlPalette.teal50;
        fg = EtlPalette.teal700;
        border = EtlPalette.teal200;
        dot = EtlPalette.teal500;
        label = 'Processando';
        break;
      case EtlCargaStatus.falha:
        bg = EtlPalette.rose50;
        fg = EtlPalette.rose700;
        border = EtlPalette.rose200;
        dot = EtlPalette.rose600;
        label = 'Falha';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: large ? 3 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == EtlCargaStatus.processando)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: dot),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: EtlText.sans(
              12,
              weight: large ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODAL DE DETALHES
// ============================================================================

class _CargaDetailsDialog extends StatelessWidget {
  const _CargaDetailsDialog({required this.carga, required this.onViewOnMap});

  final EtlCarga carga;
  final VoidCallback onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return EtlDialogShell(
      maxWidth: 672,
      header: EtlDialogHeader(
        crossAxisAlignment: CrossAxisAlignment.start,
        onClose: () => Navigator.of(context).pop(),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: EtlPalette.teal50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EtlPalette.teal100),
          ),
          child: const Icon(
            Icons.dataset_outlined,
            size: 24,
            color: EtlPalette.teal600,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  carga.fileName,
                  style: EtlText.mono(
                    17,
                    weight: FontWeight.w700,
                    color: EtlPalette.slate900,
                  ),
                ),
                _StatusBadge(status: carga.status, large: true),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 14,
                  color: EtlPalette.slate400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Executado em ${carga.timestamp} • Pipeline PostGIS / '
                    'GeoServer',
                    style: EtlText.sans(12, color: EtlPalette.slate500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetricsGrid(carga: carga),
          const SizedBox(height: 20),
          const _IntegrityNote(),
          const SizedBox(height: 20),
          _LayersSection(carga: carga),
        ],
      ),
      footer: EtlDialogFooter(
        alignment: MainAxisAlignment.spaceBetween,
        children: [
          EtlSecondaryButton(
            label: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          EtlPrimaryButton(
            label: 'Visualizar no Mapa',
            icon: Icons.map_outlined,
            onPressed: onViewOnMap,
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.carga});

  final EtlCarga carga;

  @override
  Widget build(BuildContext context) {
    final items = <_Metric>[
      _Metric('Tamanho do Arquivo', carga.sizeLabel),
      _Metric(
        'Tempo de Processamento',
        carga.duration ?? '—',
        color: EtlPalette.teal700,
      ),
      _Metric(
        'SRID / Projeção',
        carga.sridShort ?? '—',
        small: true,
        tooltip: carga.srid,
      ),
      _Metric('Total de Feições', carga.featuresCount ?? '—'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cols = constraints.maxWidth >= 520 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in items) SizedBox(width: width, child: _MetricCard(m)),
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric(
    this.label,
    this.value, {
    this.color = EtlPalette.slate800,
    this.small = false,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final bool small;
  final String? tooltip;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    Widget value = Text(
      metric.value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: EtlText.sans(
        metric.small ? 12 : 16,
        weight: FontWeight.w700,
        color: metric.color,
      ),
    );
    if (metric.tooltip != null) {
      value = Tooltip(message: metric.tooltip!, child: value);
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EtlPalette.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            style: EtlText.sans(
              11,
              weight: FontWeight.w500,
              color: EtlPalette.slate500,
            ),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }
}

class _IntegrityNote extends StatelessWidget {
  const _IntegrityNote();

  @override
  Widget build(BuildContext context) {
    final base = EtlText.sans(12, color: EtlPalette.slate600, height: 1.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x80F0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.teal100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: EtlPalette.teal600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: 'Topologia e Integridade Espacial:',
                    style: base.copyWith(
                      fontWeight: FontWeight.w600,
                      color: EtlPalette.slate800,
                    ),
                  ),
                  const TextSpan(
                    text: ' Todas as geometrias foram validadas no banco '
                        'PostGIS com índice ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3CCFBF1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'GIST',
                        style: EtlText.mono(11, color: EtlPalette.teal800),
                      ),
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

class _LayersSection extends StatelessWidget {
  const _LayersSection({required this.carga});

  final EtlCarga carga;

  @override
  Widget build(BuildContext context) {
    final layers = carga.layers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_outlined, size: 14, color: EtlPalette.teal600),
                  const SizedBox(width: 6),
                  Text(
                    'CAMADAS EXTRAÍDAS NO POSTGIS (${layers.length})',
                    style: EtlText.sans(
                      12,
                      weight: FontWeight.w700,
                      color: EtlPalette.slate900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text.rich(
                TextSpan(
                  style: EtlText.sans(11, color: EtlPalette.slate400),
                  children: [
                    const TextSpan(text: 'Banco de Destino: '),
                    TextSpan(
                      text: 'tecsys_geodb',
                      style: EtlText.sans(
                        11,
                        weight: FontWeight.w700,
                        color: EtlPalette.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EtlPalette.slate200),
          ),
          child: layers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'As camadas serão listadas assim que o processamento for '
                    'concluído.',
                    textAlign: TextAlign.center,
                    style: EtlText.sans(12, color: EtlPalette.slate400),
                  ),
                )
              : _LayersTable(layers: layers),
        ),
      ],
    );
  }
}

class _LayersTable extends StatelessWidget {
  const _LayersTable({required this.layers});

  final List<EtlLayer> layers;

  IconData _iconFor(String type) {
    if (type.contains('Point')) return Icons.pin_drop_outlined;
    if (type.contains('Polygon')) return Icons.category_outlined;
    return Icons.show_chart;
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = EtlText.sans(
      12,
      weight: FontWeight.w600,
      color: EtlPalette.slate500,
    );

    Widget cell(Widget child, {Alignment align = Alignment.centerLeft}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Align(alignment: align, child: child),
        );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3.2),
        1: FlexColumnWidth(2.6),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.6),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: EtlPalette.slate100),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xCCF8FAFC),
            border: Border(bottom: BorderSide(color: EtlPalette.slate200)),
          ),
          children: [
            cell(Text('Tabela / Layer PostGIS', style: headerStyle)),
            cell(Text('Tipo de Geometria', style: headerStyle)),
            cell(Text('Registros', style: headerStyle)),
            cell(
              Text('Integridade', style: headerStyle),
              align: Alignment.centerRight,
            ),
          ],
        ),
        for (final layer in layers)
          TableRow(
            children: [
              cell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: EtlPalette.teal500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        layer.name,
                        style: EtlText.mono(
                          12,
                          weight: FontWeight.w500,
                          color: EtlPalette.slate800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              cell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: EtlPalette.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFor(layer.type),
                        size: 13,
                        color: EtlPalette.teal600,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          layer.type,
                          style: EtlText.mono(11, color: EtlPalette.slate700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              cell(
                Text(
                  layer.records,
                  style: EtlText.sans(
                    12,
                    weight: FontWeight.w500,
                    color: EtlPalette.slate700,
                  ),
                ),
              ),
              cell(
                _IntegrityChip(valid: layer.valid),
                align: Alignment.centerRight,
              ),
            ],
          ),
      ],
    );
  }
}

class _IntegrityChip extends StatelessWidget {
  const _IntegrityChip({required this.valid});

  final bool valid;

  @override
  Widget build(BuildContext context) {
    final fg = valid ? EtlPalette.emerald700 : EtlPalette.rose700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: valid ? EtlPalette.emerald50 : EtlPalette.rose50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: valid ? EtlPalette.emerald200 : EtlPalette.rose200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(valid ? Icons.check : Icons.close, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            valid ? 'Válida' : 'Inválida',
            style: EtlText.sans(11, weight: FontWeight.w500, color: fg),
          ),
        ],
      ),
    );
  }
}