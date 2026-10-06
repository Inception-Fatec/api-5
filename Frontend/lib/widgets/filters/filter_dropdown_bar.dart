import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/ibge_service.dart';
import 'dropdown_filter_button.dart';
import 'filter_inputs.dart';
import 'bairro_autocomplete_field.dart';

class FilterDropdownBar extends StatelessWidget {
  const FilterDropdownBar({
    super.key,
    required this.distribuidoraLabel,
    required this.cidadesDisponiveis,
    required this.cidadesSelecionadas,
    required this.onCidadeMarcada,
    required this.bairroNames,
    required this.onBairroChanged,
    required this.targetLayerOptions,
    required this.targetLayers,
    required this.onTargetLayersChanged,
    required this.rotuloNivelTensao,
    required this.conjCodes,
    required this.onConjChanged,
    required this.subCodes,
    required this.onSubChanged,
    required this.clasSubOptions,
    required this.clasSub,
    required this.onClasSubChanged,
    required this.cnaeCodes,
    required this.onCnaeChanged,
    this.totalPontos,
  });

  final String distribuidoraLabel;
  final List<Municipio> cidadesDisponiveis;
  final List<Municipio> cidadesSelecionadas;
  final ValueChanged<Municipio> onCidadeMarcada;

  final List<String> bairroNames;
  final ValueChanged<List<String>> onBairroChanged;

  final List<String> targetLayerOptions;
  final List<String> targetLayers;
  final ValueChanged<List<String>> onTargetLayersChanged;
  final String Function(String) rotuloNivelTensao;

  final List<String> conjCodes;
  final ValueChanged<List<String>> onConjChanged;

  final List<String> subCodes;
  final ValueChanged<List<String>> onSubChanged;

  final List<String> clasSubOptions;
  final List<String> clasSub;
  final ValueChanged<List<String>> onClasSubChanged;

  final List<String> cnaeCodes;
  final ValueChanged<List<String>> onCnaeChanged;

  final int? totalPontos;

  Widget _painelChip({
    required String label,
    required String hint,
    required List<String> values,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: ChipInputField(label: label, hint: hint, values: values, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.all(AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.business, size: 13, color: AppColors.textSecondary),
                        label: Text(distribuidoraLabel, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.chipBg,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      DropdownFilterButton(
                        label: cidadesSelecionadas.map((m) => m.rotulo.split(' - ').first).join(', '),
                        icon: Icons.location_city,
                        ativo: true,
                        panelBuilder: (context, fechar) => Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cidade(s)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              const Text('Marcar uma cidade nova também pula o mapa pra lá.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              ...cidadesDisponiveis.map((m) {
                                final marcada = cidadesSelecionadas.contains(m);
                                final ehAUltima = marcada && cidadesSelecionadas.length == 1;
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: marcada,
                                  title: Text(m.rotulo, style: TextStyle(color: ehAUltima ? AppColors.textSecondary : null)),
                                  activeColor: AppColors.primary,
                                  onChanged: ehAUltima ? null : (v) => onCidadeMarcada(m),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalPontos != null) ...[
                  const SizedBox(height: 4),
                  Text('$totalPontos ponto(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownFilterButton(
                        label: 'Bairro',
                        icon: Icons.signpost_outlined,
                        ativo: bairroNames.isNotEmpty,
                        panelBuilder: (context, fechar) => Padding(
                          padding: const EdgeInsets.all(14),
                          child: BairroAutocompleteField(
                            munCodes: cidadesSelecionadas.map((m) => m.codigoIbge.toString()).toList(),
                            values: bairroNames,
                            onChanged: onBairroChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterButton(
                        label: targetLayers.isEmpty ? 'Nível de Tensão' : targetLayers.map(rotuloNivelTensao).join(', '),
                        icon: Icons.bolt_outlined,
                        ativo: targetLayers.isNotEmpty,
                        panelBuilder: (context, fechar) => Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nível de Tensão', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              ...targetLayerOptions.map((opt) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: targetLayers.contains(opt),
                                    title: Text(rotuloNivelTensao(opt)),
                                    activeColor: AppColors.primary,
                                    onChanged: (v) {
                                      final novos = List<String>.from(targetLayers);
                                      if (v == true) {
                                        novos.add(opt);
                                      } else {
                                        novos.remove(opt);
                                      }
                                      onTargetLayersChanged(novos);
                                    },
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterButton(
                        label: 'Conjunto',
                        icon: Icons.hub_outlined,
                        ativo: conjCodes.isNotEmpty,
                        panelBuilder: (context, fechar) => _painelChip(
                          label: 'Conjunto Elétrico',
                          hint: 'ex: 17113',
                          values: conjCodes,
                          onChanged: onConjChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterButton(
                        label: 'Subestação',
                        icon: Icons.electrical_services_outlined,
                        ativo: subCodes.isNotEmpty,
                        panelBuilder: (context, fechar) => _painelChip(
                          label: 'Subestação',
                          hint: 'ex: SJC',
                          values: subCodes,
                          onChanged: onSubChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterButton(
                        label: 'Classe',
                        icon: Icons.category_outlined,
                        ativo: clasSub.isNotEmpty,
                        panelBuilder: (context, fechar) => Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Classe / Subclasse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: clasSubOptions
                                        .map((opt) => CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              dense: true,
                                              value: clasSub.contains(opt),
                                              title: Text(opt, style: const TextStyle(fontSize: 13)),
                                              activeColor: AppColors.primary,
                                              onChanged: (v) {
                                                final novos = List<String>.from(clasSub);
                                                if (v == true) {
                                                  novos.add(opt);
                                                } else {
                                                  novos.remove(opt);
                                                }
                                                onClasSubChanged(novos);
                                              },
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownFilterButton(
                        label: 'CNAE',
                        icon: Icons.work_outline,
                        ativo: cnaeCodes.isNotEmpty,
                        panelBuilder: (context, fechar) => _painelChip(
                          label: 'Código CNAE',
                          hint: 'ex: 3511-5/01',
                          values: cnaeCodes,
                          onChanged: onCnaeChanged,
                        ),
                      ),
                    ],
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