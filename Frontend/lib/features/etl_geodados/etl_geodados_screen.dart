import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_footer.dart';
import 'package:tecsys_app/core/widgets/card_avatar.dart';
import 'package:tecsys_app/core/widgets/card_info_row.dart';
import 'package:tecsys_app/core/widgets/list_card.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';

import 'package:tecsys_app/features/auth/data/services/auth_service.dart';

import 'carga_detalhes_dialog.dart';
import 'csv_import_dialog.dart';
import 'models/csv_import_resumo.dart';
import 'models/etl_carga.dart';
import 'services/etl_service.dart';
import 'upload_modal_dialog.dart';
import 'widgets/seletor_municipio.dart';

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
  bool _carregandoHistorico = true;
  String? _erroHistorico;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
    _carregarNomesMunicipios();
  }

  /// Baixa (uma vez) a lista do IBGE para os cards mostrarem o nome das
  /// cidades em vez do código. Se falhar, os cards mostram o código.
  Future<void> _carregarNomesMunicipios() async {
    try {
      await MunicipioService.listar();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Busca as últimas cargas gravadas no backend: o histórico não some mais
  /// ao recarregar a página, e cargas ainda em andamento voltam a ser
  /// acompanhadas (#TG-141).
  Future<void> _carregarHistorico() async {
    setState(() {
      _carregandoHistorico = true;
      _erroHistorico = null;
    });
    try {
      final List<EtlCarga> historico = await EtlService.listarCargas();
      if (!mounted) return;
      setState(() {
        // Cargas enviadas enquanto o histórico carregava ficam no topo.
        final Set<String> ids = historico.map((c) => c.id).toSet();
        final List<EtlCarga> novas =
            _cargas.where((c) => !ids.contains(c.id)).toList();
        _cargas
          ..clear()
          ..addAll(novas)
          ..addAll(historico);
        _carregandoHistorico = false;
      });
      if (_cargas.any((c) => c.status == EtlCargaStatus.processando)) {
        _iniciarPolling();
      }
    } on EtlUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _carregandoHistorico = false;
        _erroHistorico = e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoHistorico = false;
        _erroHistorico =
            'Não foi possível carregar o histórico. Verifique a conexão com o servidor.';
      });
    }
  }

  Future<void> _abrirUpload() => _abrirModal(null);

  /// Abre o upload (novo) ou retoma a escolha de municípios de uma carga
  /// que ficou "Aguardando escolha" (#TG-143).
  Future<void> _abrirModal(EtlCarga? aguardando) async {
    final nova = await UploadModalDialog.show(context, aguardando: aguardando);
    if (nova == null || !mounted) return;
    setState(() {
      final int i = _cargas.indexWhere((c) => c.id == nova.id);
      if (i >= 0) {
        _cargas[i] = nova;
      } else {
        _cargas.insert(0, nova);
      }
    });
    switch (nova.status) {
      case EtlCargaStatus.aguardandoEscolha:
        _mostrarToast('Arquivo ${nova.nomeArquivo} aguardando a escolha dos municípios. '
            'Clique no card para continuar.');
      case EtlCargaStatus.cancelado:
        _mostrarToast('Arquivo ${nova.nomeArquivo} descartado.', icone: Icons.delete_outline);
      default:
        _mostrarToast('Carga de ${nova.nomeArquivo} iniciada.');
        _iniciarPolling();
    }
  }

  /// Importação de pontos externos por CSV (#TG-90). Não entra no histórico
  /// de cargas: a resposta é síncrona e o resumo já aparece no modal.
  Future<void> _abrirImportacaoCsv() async {
    final CsvImportResumo? resumo = await CsvImportDialog.show(context);
    if (resumo == null || !mounted || resumo.importadas == 0) return;
    _mostrarToast(resumo.importadas == 1
        ? '1 ponto importado do CSV.'
        : '${resumo.importadas} pontos importados do CSV.');
  }

  void _abrirCard(EtlCarga carga) => carga.status == EtlCargaStatus.aguardandoEscolha
      ? _abrirModal(carga)
      : _abrirDetalhes(carga);

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
                          EtlPageHeader(
                            mobile: mobile,
                            onUpload: _abrirUpload,
                            onImportarCsv: podeImportarPontosCsv(
                                    AuthService.instance.role)
                                ? _abrirImportacaoCsv
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _CargaList(
                            cargas: _cargas,
                            carregando: _carregandoHistorico,
                            erro: _erroHistorico,
                            onRecarregar: _carregarHistorico,
                            onOpen: _abrirCard,
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

/// Só ADM importa pontos por CSV (o endpoint responde 403 para os demais).
/// A aba de ETL já é só de ADM (#107), mas o botão confere de novo para não
/// depender só do menu.
bool podeImportarPontosCsv(String? role) => role == 'ADM';

/// Cabeçalho da tela: título e os botões de upload do .zip e, para ADM,
/// de importação de pontos por CSV (#TG-90). Público para o teste de widget.
class EtlPageHeader extends StatelessWidget {
  const EtlPageHeader({
    super.key,
    required this.mobile,
    required this.onUpload,
    this.onImportarCsv,
  });

  final bool mobile;
  final VoidCallback onUpload;

  /// `null` esconde o botão "Importar pontos (CSV)".
  final VoidCallback? onImportarCsv;

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
        Text(
          onImportarCsv == null
              ? 'Envie arquivos .zip para processamento geoespacial e validação dos dados.'
              : 'Envie arquivos .zip para processamento geoespacial e validação dos dados, '
                  'ou importe pontos externos (candidatos, pontos a cobrir e de interesse) por CSV.',
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

    final VoidCallback? importar = onImportarCsv;
    final Widget? botaoCsv = importar == null
        ? null
        : SizedBox(
            width: mobile ? double.infinity : null,
            child: OutlinedButton.icon(
              onPressed: importar,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Importar pontos (CSV)'),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile) ...[
          title,
          const SizedBox(height: AppSpacing.md),
          button,
          if (botaoCsv != null) ...[
            const SizedBox(height: AppSpacing.sm),
            botaoCsv,
          ],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.lg),
              if (botaoCsv != null) ...[
                botaoCsv,
                const SizedBox(width: AppSpacing.sm),
              ],
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
    required this.carregando,
    required this.erro,
    required this.onRecarregar,
    required this.onOpen,
    required this.onUpload,
  });

  final List<EtlCarga> cargas;
  final bool carregando;
  final String? erro;
  final VoidCallback onRecarregar;
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
              child: Text('Histórico de cargas',
                  style: AppTextStyles.sectionLabel),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: carregando ? null : onRecarregar,
              icon: const Icon(Icons.refresh, size: 20),
            ),
            const SizedBox(width: AppSpacing.xs),
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
        if (erro != null) ...[
          Text(erro!, style: AppTextStyles.bodySmallError),
          const SizedBox(height: AppSpacing.md),
        ],
        if (carregando && cargas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (cargas.isEmpty)
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
          const Text('Nenhuma carga enviada ainda',
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
      EtlCargaStatus.aguardandoEscolha => (AppColors.warning, AppColors.warningBg),
      EtlCargaStatus.cancelado => (AppColors.textSecondary, AppColors.chipBg),
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
        if (carga.status == EtlCargaStatus.processando)
          CardInfoRow(
            icon: Icons.sync,
            text: 'Etapa: ${carga.etapa ?? 'na fila'}',
            color: AppColors.primary,
          ),
        if (carga.status == EtlCargaStatus.aguardandoEscolha)
          const CardInfoRow(
            icon: Icons.touch_app_outlined,
            text: 'Clique para escolher os municípios e iniciar a carga.',
            color: AppColors.warning,
          ),
        if (carga.duracao != null)
          CardInfoRow(
              icon: Icons.timer_outlined, text: 'Duração: ${carga.duracao}'),
        if (carga.municipios.isNotEmpty)
          CardInfoRow(
            icon: Icons.location_on_outlined,
            text: MunicipioService.rotulosDe(carga.municipios),
          ),
        for (final aviso in carga.avisos)
          CardInfoRow(
            icon: Icons.warning_amber_rounded,
            text: aviso,
            color: AppColors.warning,
          ),
        if ((carga.status == EtlCargaStatus.erro ||
                carga.status == EtlCargaStatus.cancelado) &&
            carga.errorMessage != null)
          CardInfoRow(
            icon: Icons.error_outline,
            text: carga.errorMessage!,
            color: AppColors.error,
          ),
      ],
    );
  }
}
