import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Ajuda de uma tela (#TG-153): para que serve, o passo a passo e as
/// seções com o significado de cada parte. Os textos ficam em
/// `textos_ajuda.dart` e são os mesmos do manual do usuário (#TG-93).
class AjudaTela {
  final String titulo;
  final String objetivo;
  final List<String> passos;
  final List<AjudaSecao> secoes;

  const AjudaTela({
    required this.titulo,
    required this.objetivo,
    this.passos = const [],
    this.secoes = const [],
  });
}

/// Um bloco da ajuda: título e itens "termo: explicação". [cor] e [forma]
/// desenham a marca da legenda do mapa ao lado do termo.
class AjudaSecao {
  final String titulo;
  final List<AjudaItem> itens;

  const AjudaSecao(this.titulo, this.itens);
}

class AjudaItem {
  final String termo;
  final String explicacao;
  final Color? cor;
  final AjudaMarca? marca;

  const AjudaItem(this.termo, this.explicacao, {this.cor, this.marca});
}

/// Formato da marca da legenda (bolinha, losango ou quadrado).
enum AjudaMarca { bolinha, losango, quadrado }

/// Botão "?" que abre a ajuda da tela.
class AjudaBotao extends StatelessWidget {
  const AjudaBotao(
      {super.key, required this.ajuda, this.cor, this.tamanho = 22});

  final AjudaTela ajuda;
  final Color? cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key('ajuda-${ajuda.titulo}'),
      tooltip: 'Ajuda: ${ajuda.titulo}',
      icon: Icon(Icons.help_outline_rounded,
          size: tamanho, color: cor ?? AppColors.textSecondary),
      onPressed: () => mostrarAjuda(context, ajuda),
    );
  }
}

/// Abre o painel de ajuda: diálogo no computador, folha inferior no celular.
Future<void> mostrarAjuda(BuildContext context, AjudaTela ajuda) {
  final largura = MediaQuery.sizeOf(context).width;
  if (largura < AppBreakpoints.web) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scroll) =>
            _PainelAjuda(ajuda: ajuda, scroll: scroll),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: _PainelAjuda(ajuda: ajuda),
      ),
    ),
  );
}

class _PainelAjuda extends StatelessWidget {
  const _PainelAjuda({required this.ajuda, this.scroll});

  final AjudaTela ajuda;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
          child: Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(ajuda.titulo, style: AppTextStyles.cardTitle)),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            controller: scroll,
            shrinkWrap: true,
            // No celular a folha passa por baixo da barra de navegação do
            // Android (useSafeArea só protege o topo): soma a altura dela
            // para o fim do texto não ficar escondido.
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              Text(ajuda.objetivo, style: AppTextStyles.bodyMuted),
              if (ajuda.passos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Text('Passo a passo', style: AppTextStyles.sectionLabel),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < ajuda.passos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 22,
                            child: Text('${i + 1}.',
                                style: AppTextStyles.fieldLabel)),
                        Expanded(
                            child: Text(ajuda.passos[i],
                                style: AppTextStyles.input)),
                      ],
                    ),
                  ),
              ],
              for (final secao in ajuda.secoes) ...[
                const SizedBox(height: AppSpacing.md),
                Text(secao.titulo, style: AppTextStyles.sectionLabel),
                for (final item in secao.itens) _Item(item: item),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final AjudaItem item;

  @override
  Widget build(BuildContext context) {
    final cor = item.cor;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cor != null) ...[
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _marca(cor, item.marca ?? AjudaMarca.bolinha)),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${item.termo}: ', style: AppTextStyles.fieldLabel),
              TextSpan(text: item.explicacao, style: AppTextStyles.input),
            ])),
          ),
        ],
      ),
    );
  }

  static Widget _marca(Color cor, AjudaMarca marca) => switch (marca) {
        AjudaMarca.bolinha => Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        AjudaMarca.quadrado => Container(width: 11, height: 11, color: cor),
        AjudaMarca.losango => Transform.rotate(
            angle: 0.785398,
            child: Container(width: 10, height: 10, color: cor),
          ),
      };
}

/// Ícone "i" com tooltip para campos técnicos (#TG-153). No celular, tocar
/// mostra a explicação.
class AjudaDica extends StatelessWidget {
  const AjudaDica(this.texto, {super.key, this.tamanho = 16});

  final String texto;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: texto,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 8),
      waitDuration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.info_outline_rounded,
            size: tamanho, color: AppColors.textSecondary),
      ),
    );
  }
}
