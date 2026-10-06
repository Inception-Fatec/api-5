import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PointDetailSheet extends StatelessWidget {
  const PointDetailSheet({super.key, required this.feature});

  final Map<String, dynamic> feature;

  static Future<void> mostrar(BuildContext context, {required Map<String, dynamic> feature}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => PointDetailSheet(feature: feature),
    );
  }

  static const _rotulos = {
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
    'nome': 'Nome',
    'dist': 'Distribuidora (código)',
  };

  static const _rotuloCamada = {
    'ALTO': 'Alta Tensão',
    'MEDIO': 'Média Tensão',
    'BAIXO': 'Baixa Tensão',
    'SUB': 'Subestação',
  };

  @override
  Widget build(BuildContext context) {
    final props = (feature['properties'] as Map<String, dynamic>?) ?? const {};
    final id = props['id']?.toString() ?? '—';
    final layer = props['layer']?.toString();
    final nome = props['nome']?.toString();

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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.infoBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome ?? id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (nome != null) Text(id, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (layer != null)
                        Text(_rotuloCamada[layer] ?? layer, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),
            // Mostra na ordem de _rotulos, pulando: id/layer (já no
            // cabeçalho), nome (idem) e qualquer valor nulo.
            ..._rotulos.entries.where((e) => e.key != 'nome' && props[e.key] != null).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.value, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Flexible(
                          child: Text(
                            '${props[e.key]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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