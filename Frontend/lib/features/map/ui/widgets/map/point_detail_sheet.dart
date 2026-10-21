import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class PointDetailSheet extends StatelessWidget {
  final MapPoint point;

  const PointDetailSheet({super.key, required this.point});

  static Future<void> mostrar(BuildContext context, {required MapPoint point}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PointDetailSheet(point: point),
    );
  }

  static const _rotulos = <String, String>{
    'mun': 'Município (IBGE)',
    'brr': 'Bairro',
    'sub': 'Subestação',
    'conj': 'Conjunto Elétrico',
    'clas_sub': 'Classe / Subclasse',
    'cnae': 'CNAE',
    'car_inst': 'Carga Instalada (kW)',
    'dem_cont': 'Demanda Contratada (kW)',
    'tip_sist': 'Tipo de Sistema',
    'are_loc': 'Área de Localização',
    'uni_tr_mt': 'Transformador MT',
    'uni_tr_at': 'Transformador AT',
    'dist': 'Distribuidora (código)',
  };

  static const _rotuloCamada = {
    'ALTO': 'Alta Tensão',
    'MEDIO': 'Média Tensão',
    'BAIXO': 'Baixa Tensão',
    'SUB': 'Subestação',
  };

  static const _noCabecalho = {'id', 'layer', 'nome'};

  static String? _texto(Object? valor) {
    if (valor == null) return null;
    final t = valor.toString().trim();
    if (t.isEmpty || t.toLowerCase() == 'null') return null;
    return t;
  }

  List<(String, String)> _linhas(Map<String, dynamic> props) {
    final linhas = <(String, String)>[];
    for (final MapEntry(:key, :value) in _rotulos.entries) {
      final v = _texto(props[key]);
      if (v != null) linhas.add((value, v));
    }
    for (final MapEntry(:key, :value) in props.entries) {
      if (_rotulos.containsKey(key) || _noCabecalho.contains(key)) continue;
      final v = _texto(value);
      if (v != null) linhas.add((key, v));
    }
    return linhas;
  }

  @override
  Widget build(BuildContext context) {
    final props = point.properties;
    final id = _texto(props['id']) ?? '—';
    final nome = _texto(props['nome']);
    final camada = _texto(props['layer']);
    final linhas = _linhas(props);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: MapStyles.detailIconBoxSize,
                  height: MapStyles.detailIconBoxSize,
                  decoration: BoxDecoration(
                    color: AppColors.infoBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      size: MapStyles.detailIconSize, color: AppColors.infoBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome ?? id, style: MapStyles.detailTitle),
                      if (nome != null)
                        Text(id, style: MapStyles.detailRowLabel),
                      if (camada != null)
                        Text(_rotuloCamada[camada] ?? camada,
                            style: MapStyles.detailRowLabel),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            if (linhas.isEmpty)
              const Padding(
                padding: MapStyles.detailRowPadding,
                child: Text('Sem outras informações para este ponto.',
                    style: MapStyles.detailRowLabel),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (rotulo, valor) in linhas)
                        Padding(
                          padding: MapStyles.detailRowPadding,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rotulo, style: MapStyles.detailRowLabel),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  valor,
                                  textAlign: TextAlign.right,
                                  style: MapStyles.detailRowValue,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
