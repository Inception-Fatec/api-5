import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'carga_detalhes_dialog.dart';
import 'etl_theme.dart';
import 'models/etl_carga.dart';
import 'upload_modal_dialog.dart';
import 'widgets/etl_buttons.dart';

/// Tela "Execuções de ETL e Cargas Espaciais" (Módulo GEO).
class EtlGeodadosScreen extends StatefulWidget {
  const EtlGeodadosScreen({super.key});

  @override
  State<EtlGeodadosScreen> createState() => _EtlGeodadosScreenState();
}

class _EtlGeodadosScreenState extends State<EtlGeodadosScreen> {
  // Lista SEMPRE tipada. Se vier do backend, usa EtlCarga.listFromJson(resposta).
  List<EtlCarga> _cargas = EtlCarga.amostras();

  Future<void> _abrirUpload() async {
    final EtlCarga? nova = await UploadModalDialog.show(context);
    if (nova == null || !mounted) return;
    setState(() => _cargas = <EtlCarga>[nova, ..._cargas]);
    _mostrarToast('Arquivo ${nova.nomeArquivo} enviado com sucesso! Clique para ver os detalhes.');
  }

  Future<void> _abrirDetalhes(EtlCarga carga) async {
    final bool? verNoMapa = await CargaDetalhesDialog.show(context, carga);
    if (verNoMapa == true && mounted) {
      _mostrarToast('Carregando camadas no visualizador de mapa...', icone: Icons.map_outlined);
    }
  }

  void _mostrarToast(String mensagem, {IconData icone = Icons.check_circle_outline}) {
    final double largura = MediaQuery.of(context).size.width;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EtlColors.slate900,
        elevation: 8,
        duration: const Duration(milliseconds: 3500),
        margin: EdgeInsets.only(left: math.max(24.0, largura - 24 - 480), right: 24, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(icone, size: 18, color: EtlColors.teal400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: etlText(12, color: Colors.white, lineHeight: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EtlColors.slate50,
      body: Column(
        children: [
          const _TopNavbar(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Cabecalho(onNovoUpload: _abrirUpload),
                        const SizedBox(height: 24),
                        _ListaCargas(cargas: _cargas, onTap: _abrirDetalhes),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const _Rodape(),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Navbar ───────────────────────────────

class _TopNavbar extends StatelessWidget {
  const _TopNavbar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: EtlColors.slate200)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                const _Logo(),
                const SizedBox(width: 32),
                const _NavItem(label: 'Projetos'),
                const SizedBox(width: 4),
                const _NavItem(label: 'Mapa', icone: Icons.map_outlined),
                const SizedBox(width: 4),
                const _NavItem(label: 'Usuários'),
                const SizedBox(width: 4),
                const _NavItem(label: 'ETL & Geodados', icone: Icons.storage_outlined, ativo: true),
                const SizedBox(width: 4),
                const _NavItem(label: 'Configurações'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: EtlColors.slate100,
                    border: Border.all(color: EtlColors.slate200),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ambiente: Produção',
                    style: etlText(12, weight: FontWeight.w500, color: EtlColors.slate500, lineHeight: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: EtlColors.slate200, shape: BoxShape.circle),
                  child: Text(
                    'AD',
                    style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Admin Tecsys',
                  style: etlText(12, weight: FontWeight.w500, color: EtlColors.slate700, lineHeight: 16),
                ),
              ],
            ),
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
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EtlColors.teal600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: EtlColors.black5, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            'T',
            style: etlText(18, weight: FontWeight.w700, color: Colors.white, lineHeight: 28),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Tecsys',
          style: etlText(18,
              weight: FontWeight.w700, color: EtlColors.slate900, lineHeight: 28, letterSpacing: -0.45),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.label, this.icone, this.ativo = false});

  final String label;
  final IconData? icone;
  final bool ativo;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool ativo = widget.ativo;
    final Color corTexto = ativo
        ? EtlColors.teal700
        : (_hover ? EtlColors.slate900 : EtlColors.slate600);
    final Color fundo = ativo
        ? EtlColors.teal50
        : (_hover ? EtlColors.slate100 : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icone != null) ...[
              Icon(widget.icone, size: 16, color: corTexto),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: etlText(14,
                  weight: ativo ? FontWeight.w600 : FontWeight.w500, color: corTexto, lineHeight: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Cabeçalho da página ───────────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.onNovoUpload});

  final VoidCallback onNovoUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EtlColors.slate200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: EtlColors.teal100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'MÓDULO GEO',
                    style: etlText(12,
                        weight: FontWeight.w600,
                        color: EtlColors.teal800,
                        lineHeight: 16,
                        letterSpacing: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Execuções de ETL e Cargas Espaciais',
                  style: etlText(24,
                      weight: FontWeight.w700,
                      color: EtlColors.slate900,
                      lineHeight: 32,
                      letterSpacing: -0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  'Carregue arquivos compactados (.zip) para processamento geoespacial, validação topológica e persistência.',
                  style: etlText(14, color: EtlColors.slate500, lineHeight: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          EtlPrimaryButton(
            label: 'Novo Upload (.zip)',
            icon: Icons.upload_file_outlined,
            onPressed: onNovoUpload,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Lista de cargas ───────────────────────────────

class _ListaCargas extends StatelessWidget {
  const _ListaCargas({required this.cargas, required this.onTap});

  final List<EtlCarga> cargas;
  final ValueChanged<EtlCarga> onTap;

  @override
  Widget build(BuildContext context) {
    final int n = cargas.length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: EtlColors.slate200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: EtlColors.black5, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EtlColors.slate50,
              border: Border(bottom: BorderSide(color: EtlColors.slate200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: EtlColors.slate400),
                const SizedBox(width: 8),
                Text(
                  'Últimas Cargas (.zip)',
                  style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: EtlColors.slate200a80,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$n ${n == 1 ? 'item' : 'itens'}',
                    style: etlText(11, weight: FontWeight.w700, color: EtlColors.slate600, lineHeight: 16.5),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.touch_app_outlined, size: 14, color: EtlColors.slate400),
                const SizedBox(width: 4),
                Text(
                  'Clique em um card para abrir detalhes',
                  style: etlText(11, color: EtlColors.slate400, lineHeight: 16.5),
                ),
                const SizedBox(width: 12),
                Text('•', style: etlText(12, weight: FontWeight.w500, color: EtlColors.slate500, lineHeight: 16)),
                const SizedBox(width: 12),
                Text(
                  'Atualizado há poucos minutos',
                  style: etlText(12, weight: FontWeight.w500, color: EtlColors.slate500, lineHeight: 16),
                ),
              ],
            ),
          ),
          for (int i = 0; i < cargas.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _CargaTile(
                carga: cargas[i],
                segunda: i > 0,
                onTap: () => onTap(cargas[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CargaTile extends StatefulWidget {
  const _CargaTile({required this.carga, required this.segunda, required this.onTap});

  final EtlCarga carga;
  final bool segunda;
  final VoidCallback onTap;

  @override
  State<_CargaTile> createState() => _CargaTileState();
}

class _CargaTileState extends State<_CargaTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final EtlCarga c = widget.carga;
    final Color borda = _hover
        ? EtlColors.teal500
        : (widget.segunda ? EtlColors.slate100 : EtlColors.teal500Clear);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, _hover ? -2.0 : 0.0, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? EtlColors.teal50a30 : EtlColors.teal50Clear,
            border: Border.all(color: borda),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hover
                ? const [
                    BoxShadow(color: EtlColors.black10, blurRadius: 6, spreadRadius: -1, offset: Offset(0, 4)),
                    BoxShadow(color: EtlColors.black10, blurRadius: 4, spreadRadius: -2, offset: Offset(0, 2)),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hover ? EtlColors.teal600 : EtlColors.teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_zip_outlined,
                  size: 20,
                  color: _hover ? Colors.white : EtlColors.teal700,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nomeArquivo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: etlText(14,
                          weight: FontWeight.w500,
                          color: _hover ? EtlColors.teal700 : EtlColors.slate800,
                          lineHeight: 20,
                          mono: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.resumo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: etlText(12, color: EtlColors.slate400, lineHeight: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _StatusBadge(status: c.status, rotulo: c.statusLabel),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detalhes',
                      style: etlText(12,
                          weight: FontWeight.w600,
                          color: _hover ? EtlColors.teal600 : EtlColors.slate400,
                          lineHeight: 16),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(_hover ? 4.0 : 0.0, 0, 0),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: _hover ? EtlColors.teal600 : EtlColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.rotulo});

  final EtlCargaStatus status;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    late final Color fundo;
    late final Color borda;
    late final Color texto;
    late final Color ponto;
    switch (status) {
      case EtlCargaStatus.concluido:
        fundo = EtlColors.emerald50;
        borda = EtlColors.emerald200;
        texto = EtlColors.emerald700;
        ponto = EtlColors.emerald500;
      case EtlCargaStatus.processando:
        fundo = EtlColors.teal50;
        borda = EtlColors.teal200;
        texto = EtlColors.teal700;
        ponto = EtlColors.teal500;
      case EtlCargaStatus.erro:
        fundo = const Color(0xFFFFF1F2);
        borda = EtlColors.rose200;
        texto = EtlColors.rose700;
        ponto = EtlColors.rose600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Text(rotulo, style: etlText(12, weight: FontWeight.w500, color: texto, lineHeight: 16)),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Rodapé ───────────────────────────────

class _Rodape extends StatelessWidget {
  const _Rodape();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: EtlColors.slate200)),
      ),
      child: Text(
        'Tecsys B2B Platform • Gestão e Processamento Espacial',
        textAlign: TextAlign.center,
        style: etlText(12, color: EtlColors.slate400, lineHeight: 16),
      ),
    );
  }
}
