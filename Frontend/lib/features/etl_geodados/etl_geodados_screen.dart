import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/app_filter_chip.dart';
import 'package:tecsys_app/core/widgets/app_footer.dart';
import 'package:tecsys_app/core/widgets/app_search_field.dart';
import 'package:tecsys_app/core/widgets/card_avatar.dart';
import 'package:tecsys_app/core/widgets/card_info_row.dart';
import 'package:tecsys_app/core/widgets/list_card.dart';
import 'package:tecsys_app/core/widgets/metric_card.dart';
import 'package:tecsys_app/core/widgets/page_body.dart';
import 'package:tecsys_app/core/widgets/page_title.dart';
import 'package:tecsys_app/core/widgets/primary_action_button.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';

import 'carga_detalhes_dialog.dart';
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

  /// Filtro do histórico: tudo, só cargas do .zip ou só importações de CSV.
  FiltroHistorico _filtro = FiltroHistorico.todos;

  /// Texto da busca (arquivo, município ou distribuidora).
  String _busca = '';

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

  /// Abre o modal único de envio (.zip ou .csv, #TG-90) ou retoma a escolha
  /// de municípios de uma carga que ficou "Aguardando escolha" (#TG-143).
  Future<void> _abrirModal(EtlCarga? aguardando) async {
    final ResultadoEnvio? resultado =
        await UploadModalDialog.show(context, aguardando: aguardando);
    if (resultado == null || !mounted) return;

    // Cada envio de CSV (sucesso ou falha) é gravado pelo backend no mesmo
    // histórico das cargas: recarrega para o item aparecer na lista.
    final int pontos = resultado.pontosImportados;
    if (pontos > 0) {
      _mostrarToast(pontos == 1
          ? '1 ponto importado do CSV.'
          : '$pontos pontos importados do CSV.');
    }
    if (resultado.houveCsv) unawaited(_carregarHistorico());

    final EtlCarga? nova = resultado.carga;
    if (nova == null) return;
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
    // A busca vale para os chips e para a lista (como em Projetos).
    final List<EtlCarga> buscadas = buscarNoHistorico(_cargas, _busca);
    final List<EtlCarga> visiveis = filtrarHistorico(buscadas, _filtro);
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool web = constraints.maxWidth >= AppBreakpoints.web;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: web ? _paddingWeb : _paddingMobile,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EtlPageHeader(mobile: !web, total: _cargas.length, onUpload: _abrirUpload),
                      const SizedBox(height: AppSpacing.lg),
                      _Metricas(cargas: _cargas),
                      const SizedBox(height: AppSpacing.lg),
                      AppSearchField(
                        hint: 'Buscar por arquivo, município ou distribuidora...',
                        initialText: _busca,
                        onChanged: (v) => setState(() => _busca = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: FiltroHistoricoChips(
                              cargas: buscadas,
                              filtro: _filtro,
                              onFiltro: (f) => setState(() => _filtro = f),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Atualizar',
                            onPressed: _carregandoHistorico ? null : _carregarHistorico,
                            icon: const Icon(Icons.refresh, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _CargaList(
                        cargas: visiveis,
                        temAlguma: _cargas.isNotEmpty,
                        carregando: _carregandoHistorico,
                        erro: _erroHistorico,
                        onRecarregar: _carregarHistorico,
                        onOpen: _abrirCard,
                        onUpload: _abrirUpload,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

  // Mesmas margens das telas de Projetos e Usuários.
  static const EdgeInsets _paddingWeb =
      EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg);
  static const EdgeInsets _paddingMobile = EdgeInsets.all(AppSpacing.lg);
}

/// Título com o contador e o botão "Enviar arquivo", que abre o modal único
/// (.zip da BDGD ou .csv de pontos externos, #TG-90) — mesmo arranjo das
/// telas de Projetos e Usuários. Público para o teste de widget.
class EtlPageHeader extends StatelessWidget {
  const EtlPageHeader({super.key, required this.mobile, required this.onUpload, this.total = 0});

  final bool mobile;
  final VoidCallback onUpload;

  /// Itens no histórico (cargas do .zip + importações de CSV).
  final int total;

  @override
  Widget build(BuildContext context) {
    final Widget titulo = PageTitle(
      title: 'ETL & Geodados', // mesmo nome da aba, como em Projetos e Usuários
      countLabel: '$total ${total == 1 ? 'item' : 'itens'}',
      fontSize: mobile ? 24 : 26,
    );
    if (!mobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titulo),
          PrimaryActionButton(
              label: 'Enviar arquivo', icon: Icons.upload_file_outlined, onPressed: onUpload, full: false),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titulo,
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
            label: 'Enviar arquivo', icon: Icons.upload_file_outlined, onPressed: onUpload, full: true),
      ],
    );
  }
}

/// Linha de métricas, no mesmo formato de Projetos e Usuários.
class _Metricas extends StatelessWidget {
  const _Metricas({required this.cargas});

  final List<EtlCarga> cargas;

  @override
  Widget build(BuildContext context) {
    final int concluidas = cargas.where((c) => c.status == EtlCargaStatus.concluido).length;
    final int falhas = cargas.where((c) => c.status == EtlCargaStatus.erro).length;
    return Row(
      children: [
        Expanded(
          child: MetricCard(label: 'TOTAL', icon: Icons.storage_outlined, value: '${cargas.length}'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
              label: 'SUCESSO', icon: Icons.check_circle_outline, value: '$concluidas'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            label: 'FALHAS',
            icon: Icons.error_outline,
            value: '$falhas',
            valueColor: falhas > 0 ? AppColors.error : null,
          ),
        ),
      ],
    );
  }
}

/// Filtro do histórico de cargas (#TG-90): as importações de CSV entram na
/// mesma lista das cargas da BDGD.
enum FiltroHistorico { todos, etl, csv }

/// Itens do histórico que o filtro mostra.
List<EtlCarga> filtrarHistorico(List<EtlCarga> cargas, FiltroHistorico filtro) =>
    switch (filtro) {
      FiltroHistorico.todos => cargas,
      FiltroHistorico.etl => cargas.where((c) => !c.ehCsv).toList(),
      FiltroHistorico.csv => cargas.where((c) => c.ehCsv).toList(),
    };

/// Busca por nome do arquivo, município ou distribuidora (sem diferenciar
/// maiúsculas). Busca vazia devolve tudo.
List<EtlCarga> buscarNoHistorico(List<EtlCarga> cargas, String busca) {
  final String q = busca.trim().toLowerCase();
  if (q.isEmpty) return cargas;
  return cargas.where((c) {
    final String texto = [
      c.nomeArquivo,
      MunicipioService.rotulosDe(c.municipios),
      if (c.ehCsv) c.origemCsv,
    ].join(' ').toLowerCase();
    return texto.contains(q);
  }).toList();
}

/// Chips "Todos (n) | ETL (n) | CSV (n)", no padrão do filtro de Projetos.
class FiltroHistoricoChips extends StatelessWidget {
  const FiltroHistoricoChips({
    super.key,
    required this.cargas,
    required this.filtro,
    required this.onFiltro,
  });

  final List<EtlCarga> cargas;
  final FiltroHistorico filtro;
  final ValueChanged<FiltroHistorico> onFiltro;

  @override
  Widget build(BuildContext context) {
    AppFilterChip chip(FiltroHistorico f, String rotulo) => AppFilterChip(
          label: '$rotulo (${filtrarHistorico(cargas, f).length})',
          selected: filtro == f,
          onTap: () => onFiltro(f),
        );
    return AppFilterChipRow(chips: [
      chip(FiltroHistorico.todos, 'Todos'),
      chip(FiltroHistorico.etl, 'ETL'),
      chip(FiltroHistorico.csv, 'CSV'),
    ]);
  }
}

/// Lista de cards (largura total, como a tela já era), com os estados de
/// carregando, erro e vazio no formato da lista de Projetos.
class _CargaList extends StatelessWidget {
  const _CargaList({
    required this.cargas,
    required this.temAlguma,
    required this.carregando,
    required this.erro,
    required this.onRecarregar,
    required this.onOpen,
    required this.onUpload,
  });

  /// Itens já filtrados pela busca e pelos chips.
  final List<EtlCarga> cargas;

  /// O histórico tem algum item (antes da busca e do filtro).
  final bool temAlguma;
  final bool carregando;
  final String? erro;
  final VoidCallback onRecarregar;
  final ValueChanged<EtlCarga> onOpen;
  final VoidCallback onUpload;

  static const EdgeInsets _paddingMensagem = EdgeInsets.symmetric(vertical: 32);

  @override
  Widget build(BuildContext context) {
    if (carregando && !temAlguma) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (erro != null && !temAlguma) {
      return Padding(
        padding: _paddingMensagem,
        child: Center(
          child: Column(
            children: [
              Text(erro!, style: AppTextStyles.bodyError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRecarregar, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }
    if (!temAlguma) return _EmptyState(onUpload: onUpload);
    if (cargas.isEmpty) {
      return const Padding(
        padding: _paddingMensagem,
        child: Center(
          child: Text('Nenhum item encontrado para essa busca ou filtro.', style: AppTextStyles.bodyMuted),
        ),
      );
    }

    final List<Widget> cards = [
      for (final EtlCarga c in cargas) _CargaCard(key: ValueKey(c.id), carga: c, onTap: () => onOpen(c)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (erro != null) ...[
          Text(erro!, style: AppTextStyles.bodySmallError),
          const SizedBox(height: AppSpacing.md),
        ],
        // Cards em largura total, um embaixo do outro (como a tela já era).
        for (final Widget card in cards) ...[
          card,
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Estado vazio (nada enviado ainda), no formato do de Projetos.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            const Text('Nenhum arquivo enviado ainda',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Envie um .zip com a BDGD ou um .csv de pontos externos.',
              style: AppTextStyles.bodySmallMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryActionButton(
                label: 'Enviar arquivo', icon: Icons.upload_file_outlined, onPressed: onUpload, full: false),
          ],
        ),
      ),
    );
  }
}

class _CargaCard extends StatelessWidget {
  const _CargaCard({super.key, required this.carga, required this.onTap});

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
      leading: CardAvatar(
          color: AppColors.primary,
          icon: carga.ehCsv ? Icons.description_outlined : Icons.folder_zip_outlined),
      badge: StatusBadge(
          label: carga.statusLabel, color: color, softColor: softColor),
      onDelete: null,
      showDelete: false,
      title: carga.nomeArquivo,
      subtitle: carga.resumo,
      accentColor: AppColors.primary,
      onTap: onTap,
      infoRows: [
        if (carga.ehCsv)
          CardInfoRow(
            icon: Icons.add_location_alt_outlined,
            text: carga.origemCsv,
          ),
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
