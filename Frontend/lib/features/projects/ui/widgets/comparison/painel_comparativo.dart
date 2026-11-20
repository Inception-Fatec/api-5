import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/state/comparacao_controller.dart';
import 'package:tecsys_app/features/projects/ui/comparacao_textos.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';

/// Um indicador comparado nas barras.
class _Metrica {
  const _Metrica(this.titulo, this.valor, this.formatar, {required this.maiorMelhor});

  final String titulo;
  final double Function(ReportSummary s) valor;
  final String Function(double v) formatar;
  final bool maiorMelhor;
}

final _metricas = [
  _Metrica('Cobertura', (s) => s.coveragePercentage, formatPercent,
      maiorMelhor: true),
  _Metrica('Gateways', (s) => s.selectedGateways.toDouble(),
      (v) => formatInt(v.round()),
      maiorMelhor: false),
  _Metrica('Consumidores por gateway', consumidoresPorGateway, formatDecimal,
      maiorMelhor: true),
];

/// Topo da comparação: quem é cada letra, barras por indicador com o melhor
/// destacado, a leitura de cada cenário e o aviso quando as áreas diferem.
class PainelComparativo extends StatelessWidget {
  const PainelComparativo({super.key, required this.controller});

  final ComparacaoController controller;

  @override
  Widget build(BuildContext context) {
    final cenarios = controller.cenarios;
    final carregados = [
      for (var i = 0; i < cenarios.length; i++)
        if (cenarios[i].relatorio != null) (letraCenario(i), cenarios[i]),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text('Comparativo', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < cenarios.length; i++)
                _ChaveCenario(
                    letra: letraCenario(i),
                    nome: cenarios[i].projeto.name,
                    referencia: i == 0),
            ],
          ),
          if (!controller.carregou) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.xs),
            const Text('Carregando os relatórios...', style: AppTextStyles.caption),
          ],
          if (carregados.length >= 2) ...[
            for (final m in _metricas) _BlocoMetrica(metrica: m, cenarios: carregados),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 1; i < cenarios.length; i++)
              if (controller.delta(cenarios[i]) case final d?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(leituraCenario(letraCenario(i), d),
                            key: Key('leitura-${cenarios[i].projeto.id}'),
                            style: AppTextStyles.input),
                      ),
                    ],
                  ),
                ),
          ],
          if (controller.carregou && controller.areasDiferentes)
            _Aviso(
              'Os cenários cobrem áreas diferentes (${_porLetra((c) => _area(c))}). '
              'A cobertura % pode ser comparada; o número de gateways e de '
              'consumidores depende do tamanho de cada área.',
            )
          else if (controller.carregou && controller.totaisDiferentes)
            _Aviso(
              'Os cenários consideram totais diferentes de consumidores '
              '(${_porLetra((c) => formatInt(c.relatorio?.summary.totalPoints ?? 0))}), '
              'por causa dos filtros ou da área desenhada. Compare a cobertura % '
              'e os consumidores por gateway.',
            ),
        ],
      ),
    );
  }

  String _porLetra(String Function(CenarioComparado c) texto) => [
        for (var i = 0; i < controller.cenarios.length; i++)
          '${letraCenario(i)}: ${texto(controller.cenarios[i])}',
      ].join(' · ');

  static String _area(CenarioComparado c) => c.projeto.munCodes.isEmpty
      ? nomeDistribuidora(c.projeto.distCode)
      : IbgeService.rotulosMunicipios(c.projeto.munCodes);
}

class _ChaveCenario extends StatelessWidget {
  const _ChaveCenario({required this.letra, required this.nome, required this.referencia});

  final String letra;
  final String nome;
  final bool referencia;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: referencia ? AppColors.primary : AppColors.chipBg,
          child: Text(letra,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: referencia ? Colors.white : AppColors.primary)),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption),
        ),
      ],
    );
  }
}

/// Um indicador: uma barra por cenário, com o melhor em destaque.
class _BlocoMetrica extends StatelessWidget {
  const _BlocoMetrica({required this.metrica, required this.cenarios});

  final _Metrica metrica;
  final List<(String, CenarioComparado)> cenarios;

  @override
  Widget build(BuildContext context) {
    final valores = [for (final (_, c) in cenarios) metrica.valor(c.relatorio!.summary)];
    // Compara pelo que aparece na tela (ex.: 100,00% = 100,00%).
    final textos = valores.map(metrica.formatar).toList();
    final melhor = metrica.maiorMelhor
        ? valores.reduce((a, b) => a > b ? a : b)
        : valores.reduce((a, b) => a < b ? a : b);
    final lideres = [
      for (var i = 0; i < valores.length; i++)
        if (textos[i] == metrica.formatar(melhor)) i,
    ];
    final empate = lideres.length == valores.length;
    final escala = valores.fold<double>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(metrica.titulo, style: AppTextStyles.sectionLabel)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                empate
                    ? 'empate'
                    : '${metrica.maiorMelhor ? 'maior' : 'menor'}: '
                        '${juntarLetras([for (final i in lideres) cenarios[i].$1])}',
                key: Key('destaque-${metrica.titulo}'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: empate ? AppColors.textSecondary : AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < cenarios.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(cenarios[i].$1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.pill,
                      child: Stack(
                        children: [
                          Container(height: 10, color: AppColors.divider),
                          FractionallySizedBox(
                            widthFactor:
                                escala <= 0 ? 0 : (valores[i] / escala).clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              color: lideres.contains(i) && !empate
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 76,
                    child: Text(textos[i],
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: lideres.contains(i) && !empate
                                ? FontWeight.w800
                                : FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('aviso-comparacao'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
