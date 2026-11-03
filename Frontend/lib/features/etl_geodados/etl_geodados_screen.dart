import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_footer.dart';
import 'package:tecsys_app/core/widgets/card_avatar.dart';
import 'package:tecsys_app/core/widgets/card_info_row.dart';
import 'package:tecsys_app/core/widgets/list_card.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';

import 'carga_detalhes_dialog.dart';
import 'models/etl_carga.dart';
import 'services/etl_service.dart';
import 'upload_modal_dialog.dart';

/// Tela de execuções ETL e cargas espaciais.
class EtlGeodadosScreen extends StatefulWidget {
  const EtlGeodadosScreen({super.key});

  @override
  State<EtlGeodadosScreen> createState() => _EtlGeodadosScreenState();
}

class _EtlGeodadosScreenState extends State<EtlGeodadosScreen> {
  final List<EtlCarga> _cargas = [];
  Timer? _timer;
  bool _consultando = false;
  int _falhasSeguidas = 0;

  Future<void> _abrirUpload() async {
    final nova = await UploadModalDialog.show(context);
    if (nova == null || !mounted) return;
    setState(() => _cargas.insert(0, nova));
    _mostrarToast(
        'Arquivo ${nova.nomeArquivo} enviado. O processamento foi iniciado.');
    _iniciarPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarPolling() {
    _falhasSeguidas = 0;
    _timer ??= Timer.periodic(
        const Duration(seconds: 4), (_) => _atualizarPendentes());
  }

  Future<void> _atualizarPendentes() async {
    if (_consultando) return;
    final pendentes = _cargas
        .where((c) => c.status == EtlCargaStatus.processando)
        .toList(growable: false);
    if (pendentes.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _consultando = true;
    try {
      for (final antiga in pendentes) {
        final nova = await EtlService.consultarCarga(antiga);
        if (!mounted) return;
        setState(() {
          final index = _cargas.indexWhere((c) => c.id == nova.id);
          if (index >= 0) _cargas[index] = nova;
        });
        if (nova.status == EtlCargaStatus.concluido) {
          _mostrarToast('Carga ${nova.nomeArquivo} concluída.');
        } else if (nova.status == EtlCargaStatus.erro) {
          _mostrarToast(
            'A carga ${nova.nomeArquivo} falhou: ${nova.errorMessage ?? 'sem detalhes do servidor'}',
            icone: Icons.error_outline,
          );
        }
      }
      _falhasSeguidas = 0;
    } catch (_) {
      if (++_falhasSeguidas >= 5) {
        _timer?.cancel();
        _timer = null;
        if (mounted) {
          _mostrarToast(
            'Não foi possível acompanhar o processamento. Verifique a conexão com o servidor.',
            icone: Icons.error_outline,
          );
        }
      }
    } finally {
      _consultando = false;
    }
  }

  Future<void> _abrirDetalhes(EtlCarga carga) =>
      CargaDetalhesDialog.show(context, carga);

  void _mostrarToast(String mensagem,
      {IconData icone = Icons.check_circle_outline}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(icone, color: AppColors.onPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(mensagem)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < AppBreakpoints.web;
          final horizontal = mobile ? AppSpacing.md : AppSpacing.xl;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    horizontal,
                    mobile ? AppSpacing.lg : AppSpacing.xl,
                    horizontal,
                    AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PageHeader(
                            mobile: mobile,
                            onUpload: _abrirUpload,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _CargaList(
                            cargas: _cargas,
                            onOpen: _abrirDetalhes,
                            onUpload: _abrirUpload,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [AppFooter()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.mobile, required this.onUpload});

  final bool mobile;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Execuções de ETL e Cargas Espaciais',
          style: AppTextStyles.pageTitle(mobile ? 24 : 26),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Envie arquivos .zip para processamento geoespacial e validação dos dados.',
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );

    final button = SizedBox(
      width: mobile ? double.infinity : null,
      child: FilledButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Novo upload (.zip)'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile) ...[
          title,
          const SizedBox(height: AppSpacing.md),
          button,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.lg),
              button,
            ],
          ),
      ],
    );
  }
}

class _CargaList extends StatelessWidget {
  const _CargaList({
    required this.cargas,
    required this.onOpen,
    required this.onUpload,
  });

  final List<EtlCarga> cargas;
  final ValueChanged<EtlCarga> onOpen;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Cargas desta sessão',
                  style: AppTextStyles.sectionLabel),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: const BoxDecoration(
                  color: AppColors.chipBg, borderRadius: AppRadius.pill),
              child: Text(
                  '${cargas.length} ${cargas.length == 1 ? 'item' : 'itens'}',
                  style: AppTextStyles.countBadge),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (cargas.isEmpty)
          _EmptyState(onUpload: onUpload)
        else
          for (final carga in cargas) ...[
            _CargaCard(carga: carga, onTap: () => onOpen(carga)),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.outlinedCard,
      child: Column(
        children: [
          const Text('Nenhuma carga nesta sessão',
              style: AppTextStyles.sectionLabel, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Envie um arquivo .zip com uma geodatabase para iniciar o processamento.',
            style: AppTextStyles.bodySmallMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Selecionar arquivo'),
          ),
        ],
      ),
    );
  }
}

class _CargaCard extends StatelessWidget {
  const _CargaCard({required this.carga, required this.onTap});

  final EtlCarga carga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, softColor) = switch (carga.status) {
      EtlCargaStatus.concluido => (AppColors.success, AppColors.primarySoft),
      EtlCargaStatus.processando => (AppColors.primary, AppColors.primarySoft),
      EtlCargaStatus.erro => (AppColors.error, AppColors.warningBg),
    };
    return ListCard(
      leading: const CardAvatar(
          color: AppColors.primary, icon: Icons.folder_zip_outlined),
      badge: StatusBadge(
          label: carga.statusLabel, color: color, softColor: softColor),
      onDelete: null,
      showDelete: false,
      title: carga.nomeArquivo,
      subtitle: carga.resumo,
      accentColor: AppColors.primary,
      onTap: onTap,
      infoRows: [
        if (carga.executadoEm != null)
          CardInfoRow(icon: Icons.schedule_outlined, text: carga.executadoEm!),
        if (carga.duracao != null)
          CardInfoRow(
              icon: Icons.timer_outlined, text: 'Duração: ${carga.duracao}'),
        if (carga.status == EtlCargaStatus.erro && carga.errorMessage != null)
          CardInfoRow(
            icon: Icons.error_outline,
            text: carga.errorMessage!,
            color: AppColors.error,
          ),
      ],
    );
  }
}
