import 'package:flutter/material.dart';

import '../etl_theme.dart';
import '../models/etl_carga.dart';
import 'seletor_municipio.dart';

/// Escolha dos municípios **presentes na .gdb** (#TG-143): o backend leu o
/// arquivo e devolveu a lista com as quantidades; aqui o ADM marca quais
/// cidades carregar. Não é possível escolher cidade fora do arquivo.
class EscolhaMunicipios extends StatefulWidget {
  const EscolhaMunicipios({
    super.key,
    required this.inspecao,
    required this.onChanged,
    this.enabled = true,
  });

  final InspecaoGdb inspecao;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  /// A partir de quantas cidades a tela avisa sobre tempo e espaço no banco.
  static const int limiteAviso = 10;

  @override
  State<EscolhaMunicipios> createState() => _EscolhaMunicipiosState();
}

class _EscolhaMunicipiosState extends State<EscolhaMunicipios> {
  final Set<String> _selecionados = <String>{};
  String _busca = '';

  @override
  void initState() {
    super.initState();
    // Nomes das cidades pela lista do IBGE (em cache); sem ela, mostra o código.
    MunicipioService.listar().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {});
  }

  List<MunicipioNoArquivo> get _visiveis {
    final String termo = _normalizar(_busca);
    final List<MunicipioNoArquivo> lista = widget.inspecao.municipios
        .where((m) => termo.isEmpty || _normalizar(MunicipioService.rotuloDe(m.codigo)).contains(termo))
        .toList();
    lista.sort((a, b) => MunicipioService.rotuloDe(a.codigo).compareTo(MunicipioService.rotuloDe(b.codigo)));
    return lista;
  }

  void _alternar(String codigo) {
    setState(() {
      if (!_selecionados.remove(codigo)) _selecionados.add(codigo);
    });
    widget.onChanged(Set<String>.of(_selecionados));
  }

  void _marcarVisiveis(List<MunicipioNoArquivo> visiveis, bool marcar) {
    setState(() {
      for (final MunicipioNoArquivo m in visiveis) {
        marcar ? _selecionados.add(m.codigo) : _selecionados.remove(m.codigo);
      }
    });
    widget.onChanged(Set<String>.of(_selecionados));
  }

  @override
  Widget build(BuildContext context) {
    final InspecaoGdb insp = widget.inspecao;
    final List<MunicipioNoArquivo> visiveis = _visiveis;
    final bool todosVisiveisMarcados =
        visiveis.isNotEmpty && visiveis.every((m) => _selecionados.contains(m.codigo));
    final String periodo = insp.periodoInicio != null && insp.periodoFim != null
        ? ' · dados de ${insp.periodoInicio} a ${insp.periodoFim}'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EtlColors.teal50,
            border: Border.all(color: EtlColors.teal100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 18, color: EtlColors.teal700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Distribuidora ${insp.distribuidora}$periodo\n'
                  '${insp.municipios.length} município(s) no arquivo. Escolha quais carregar.',
                  style: etlText(12, color: EtlColors.slate700, lineHeight: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: widget.enabled,
          onChanged: (v) => setState(() => _busca = v),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: 'Buscar município',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_selecionados.length} selecionado(s)',
                style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate700, lineHeight: 16),
              ),
            ),
            TextButton(
              onPressed: !widget.enabled || visiveis.isEmpty
                  ? null
                  : () => _marcarVisiveis(visiveis, !todosVisiveisMarcados),
              child: Text(todosVisiveisMarcados
                  ? 'Desmarcar ${_busca.isEmpty ? 'todos' : 'filtrados'}'
                  : 'Selecionar ${_busca.isEmpty ? 'todos' : 'filtrados'}'),
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            border: Border.all(color: EtlColors.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: visiveis.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Nenhum município do arquivo corresponde à busca.',
                      textAlign: TextAlign.center,
                      style: etlText(12, color: EtlColors.slate500, lineHeight: 16)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: visiveis.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: EtlColors.slate100),
                  itemBuilder: (context, i) {
                    final MunicipioNoArquivo m = visiveis[i];
                    final bool marcado = _selecionados.contains(m.codigo);
                    return InkWell(
                      onTap: widget.enabled ? () => _alternar(m.codigo) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: marcado,
                              activeColor: EtlColors.teal600,
                              onChanged: widget.enabled ? (_) => _alternar(m.codigo) : null,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(MunicipioService.rotuloDe(m.codigo),
                                      style: etlText(13,
                                          weight: FontWeight.w600, color: EtlColors.slate900, lineHeight: 18)),
                                  Text(
                                    '${EtlCarga.milhar(m.transformadores)} transformadores · '
                                    '${EtlCarga.milhar(m.consumidoresBt)} consumidores BT',
                                    style: etlText(11, color: EtlColors.slate500, lineHeight: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_selecionados.length > EscolhaMunicipios.limiteAviso) ...[
          const SizedBox(height: 8),
          Text(
            'Muitos municípios deixam a carga mais lenta e ocupam mais espaço no banco '
            '(o Supabase gratuito tem 500 MB).',
            style: etlText(11, color: const Color(0xFFB45309), lineHeight: 16),
          ),
        ],
      ],
    );
  }

  static const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
  static const String _semAcento = 'aaaaaeeeeiiiiooooouuuuc';

  static String _normalizar(String s) {
    final StringBuffer b = StringBuffer();
    for (final int r in s.toLowerCase().runes) {
      final String c = String.fromCharCode(r);
      final int i = _comAcento.indexOf(c);
      b.write(i >= 0 ? _semAcento[i] : c);
    }
    return b.toString();
  }
}
