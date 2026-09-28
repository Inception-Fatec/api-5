import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../services/ibge_service.dart';
import 'selected_area.dart';

/// Opções de quanto renderizar de uma vez — null representa "todos".
/// Cidades grandes (ex: São José dos Campos) têm dezenas de milhares
/// de pontos; desenhar tudo de uma vez deixa o Flutter Web pesado, daí
/// a opção de escolher um limite menor. O total real (`total_points`,
/// vindo do backend) nunca muda — isso só limita o que é DESENHADO.
const _opcoesLimite = <int?>[20, 50, 100, 500, 1000, null];

/// Mapa da Etapa 2 do fluxo de Novo Projeto.
///
/// Mostra:
///   1. [areasCidades] — cada cidade escolhida na Etapa 1 com o seu
///      PRÓPRIO retângulo (geocoding, client-side). Cada uma tem um
///      chip com a contagem de pontos dela; tocar no chip ISOLA essa
///      cidade (esconde as outras cidades/áreas e mostra só os pontos
///      dela) — toca de novo pra voltar a ver tudo.
///   2. Os pontos reais ([features], quando o backend já responder) e
///      quantas áreas de monitoramento o usuário quiser desenhar por
///      cima — mesmo comportamento de chip + isolamento.
class PointsRefinementMap extends StatefulWidget {
  const PointsRefinementMap({
    super.key,
    this.areasCidades = const {},
    this.contagensCidades = const {},
    this.contagensAreas = const {},
    this.totalPontosBanco,
    this.onRemoverCidade,
    this.features = const [],
    this.areasMonitoramento = const [],
    this.onAreasMonitoramentoChanged,
    this.targetLayers = const [],
    this.mostrarToggleRelevo = true,
    this.height = 320,
    this.permitirDesenho = true,
  });

  /// Cidades escolhidas → sua própria área geocodificada.
  final Map<Municipio, SelectedArea> areasCidades;

  /// Contagem EXATA (do backend, `count_only`) por cidade/área — usa
  /// isso pro número do chip quando disponível; se a cidade/área
  /// ainda não tiver entrada aqui (resposta ainda não voltou), cai de
  /// volta pra estimativa local (retângulo) só como placeholder
  /// temporário, marcada com "~".
  final Map<Municipio, int> contagensCidades;
  final Map<Map<String, dynamic>, int> contagensAreas;

  /// Total oficial de pontos, vindo direto do backend (`total_points`
  /// da última busca) — usado no seletor "Todos" pra garantir que
  /// esse número sempre reflita o banco, sem depender de contagem
  /// local derivada. null enquanto ainda não veio nenhuma resposta.
  final int? totalPontosBanco;

  /// Chamado quando o X de uma cidade é tocado — só aparece quando
  /// tem mais de uma cidade selecionada (Grupo A exige pelo menos
  /// uma, então a última não pode ser removida por aqui).
  final ValueChanged<Municipio>? onRemoverCidade;

  /// Pontos (GeoJSON Feature, geometria tipo Point) retornados pela
  /// busca no backend — vazio até o endpoint existir de verdade.
  final List<Map<String, dynamic>> features;

  /// Áreas de monitoramento desenhadas manualmente — pode ter
  /// **várias**, cada uma tocando ao menos uma das cidades.
  final List<Map<String, dynamic>> areasMonitoramento;
  final ValueChanged<List<Map<String, dynamic>>>? onAreasMonitoramentoChanged;

  /// Níveis de tensão marcados (alto/medio/baixo/all) — filtra os
  /// pontos exibidos DIRETO NO CLIENTE (cada feature já vem com
  /// `properties.layer` desde a Etapa 1), sem precisar de nova
  /// chamada ao backend — fica instantâneo. Vazio ou contendo "all"
  /// = mostra todos os níveis.
  final List<String> targetLayers;

  final bool mostrarToggleRelevo;
  final double height;
  final bool permitirDesenho;

  @override
  State<PointsRefinementMap> createState() => _PointsRefinementMapState();
}

class _PointsRefinementMapState extends State<PointsRefinementMap> {
  final _mapController = MapController();

  bool _desenhandoManualmente = false;
  Offset? _dragStartOffset;
  Offset? _dragCurrentOffset;
  Rect? _retanguloPendente;

  // Qual peça está isolada agora (uma Municipio ou um dos Maps de
  // areasMonitoramento) — quando setada, o mapa mostra só ela (chip,
  // retângulo e pontos), escondendo o resto. null = mostra tudo.
  Object? _areaIsolada;
  bool _pulsoAceso = false;

  // Quantos pontos desenhar de uma vez — null = todos.
  int? _limiteRenderizacao = 20;

  bool _mostrarRelevoNasa = false;
  double _opacidadeRelevo = 0.6;
  bool _mostrarPainelCamadas = false;

  // Cache dos pontos já processados (parse do GeoJSON + filtro de
  // nível de tensão) — sem isso, cada rebuild (mesmo por coisa
  // pequena, tipo o pulso de destaque ou abrir o painel de relevo)
  // reprocessava os pontos brutos DO ZERO, várias vezes (uma pra
  // cada chip contando, outra pro total, outra pra desenhar) — com
  // dezenas de milhares de pontos, isso sozinho já travava a tela.
  // Só recalcula quando widget.features ou widget.targetLayers
  // realmente mudam (didUpdateWidget/initState), não a cada acesso.
  List<LatLng> _pontosCache = [];

  @override
  void initState() {
    super.initState();
    _pontosCache = _calcularPontos();
  }

  List<LatLng> _calcularPontos() {
    final filtroAtivo = widget.targetLayers.isNotEmpty && !widget.targetLayers.contains('all');
    final filtroLower = widget.targetLayers.map((e) => e.toLowerCase()).toSet();

    final pontos = <LatLng>[];
    for (final f in widget.features) {
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      if (filtroAtivo) {
        final props = f['properties'] as Map<String, dynamic>?;
        final layer = (props?['layer'] as String?)?.toLowerCase();
        // Filtro é client-side (o dado já veio com a camada de cada
        // ponto na Etapa 1) — não precisa de ida no backend pra
        // marcar/desmarcar nível de tensão, fica instantâneo.
        if (layer == null || !filtroLower.contains(layer)) continue;
      }

      final ponto = _extrairPontoRepresentativo(geom);
      if (ponto != null) pontos.add(ponto);
    }
    return pontos;
  }

  /// Extrai um ponto pra desenhar no mapa a partir de QUALQUER
  /// geometria — não só `Point`. Subestações (camada "SUB") vêm como
  /// `MultiPolygon` (a área dela), não como ponto — sem isso, elas
  /// entravam no `total_points` mas nunca apareciam desenhadas em
  /// lugar nenhum, deixando "diz que tem X, mostra 0" sempre que só
  /// sobrava subestação no resultado. Pra polígono, usa o centro
  /// (média dos vértices do anel externo) como aproximação — não
  /// precisa ser exato, é só pra ter ONDE mostrar aquele item no mapa.
  LatLng? _extrairPontoRepresentativo(Map<String, dynamic> geom) {
    final tipo = geom['type'];

    if (tipo == 'Point') {
      final coords = geom['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;
      return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
    }

    List? anelExterno;
    if (tipo == 'Polygon') {
      final aneis = geom['coordinates'] as List?;
      anelExterno = (aneis != null && aneis.isNotEmpty) ? aneis.first as List? : null;
    } else if (tipo == 'MultiPolygon') {
      final poligonos = geom['coordinates'] as List?;
      final primeiroPoligono = (poligonos != null && poligonos.isNotEmpty) ? poligonos.first as List? : null;
      anelExterno = (primeiroPoligono != null && primeiroPoligono.isNotEmpty) ? primeiroPoligono.first as List? : null;
    }
    if (anelExterno == null || anelExterno.isEmpty) return null;

    var somaLat = 0.0, somaLon = 0.0;
    var n = 0;
    for (final v in anelExterno) {
      final vertice = v as List;
      somaLon += (vertice[0] as num).toDouble();
      somaLat += (vertice[1] as num).toDouble();
      n++;
    }
    if (n == 0) return null;
    return LatLng(somaLat / n, somaLon / n);
  }

  List<LatLng> get _pontosLatLng => _pontosCache;

  @override
  void didUpdateWidget(covariant PointsRefinementMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.features != oldWidget.features || widget.targetLayers != oldWidget.targetLayers) {
      _pontosCache = _calcularPontos();
    }
    _atualizarCamera(oldWidget);
  }

  bool _dentro(LatLng p, SelectedArea a) => p.latitude >= a.south && p.latitude <= a.north && p.longitude >= a.west && p.longitude <= a.east;

  /// Quantos pontos (do total real) caem dentro dessa área — usado
  /// Resolve a [SelectedArea] de um id de isolamento (Municipio ou
  /// Map de área desenhada).
  SelectedArea? _areaDe(Object id) {
    if (id is Municipio) return widget.areasCidades[id];
    if (id is Map<String, dynamic>) return _areaDoPoligono(id);
    return null;
  }

  /// Pontos a desenhar de fato: se isolado, só os que caem dentro da
  /// área isolada (até o limite). Sem isolamento, reparte o limite
  /// por ÁREA (cidade ou área desenhada) em vez de cortar o total
  /// combinado — com duas cidades e limite 20, mostra até 20 de CADA
  /// uma, não só 20 no total (que ia esconder uma cidade inteira se a
  /// outra "viesse primeiro" na lista de pontos do backend).
  List<LatLng> get _pontosParaDesenhar {
    if (_areaIsolada != null) {
      final area = _areaDe(_areaIsolada!);
      final base = area == null ? _pontosLatLng : _pontosLatLng.where((p) => _dentro(p, area)).toList();
      if (_limiteRenderizacao == null || base.length <= _limiteRenderizacao!) return base;
      return base.sublist(0, _limiteRenderizacao!);
    }

    final todasAreas = <SelectedArea>[
      ...widget.areasCidades.values,
      ...widget.areasMonitoramento.map(_areaDoPoligono).whereType<SelectedArea>(),
    ];

    if (todasAreas.isEmpty || _limiteRenderizacao == null) {
      final todos = _pontosLatLng;
      if (_limiteRenderizacao == null || todos.length <= _limiteRenderizacao!) return todos;
      return todos.sublist(0, _limiteRenderizacao!);
    }

    final vistos = <LatLng>{};
    final resultado = <LatLng>[];
    for (final area in todasAreas) {
      var contador = 0;
      for (final p in _pontosLatLng) {
        if (contador >= _limiteRenderizacao!) break;
        if (!_dentro(p, area)) continue;
        if (vistos.add(p)) {
          resultado.add(p);
          contador++;
        }
      }
    }

    // "Sobra" — pontos reais (confirmados pelo backend) que não
    // caíram em nenhuma área porque o retângulo aproximado da
    // cidade (Nominatim) não é a fronteira exata, e algum ponto real
    // ficou fora dele. Sem isso, um total pequeno (ex: 9 pontos,
    // filtro bem restrito) podia sumir do mapa inteiro mesmo tendo
    // pontos de sobra — o limite nunca deveria "comer" pontos que
    // existem de verdade só por causa dessa aproximação.
    final tetoGeral = _limiteRenderizacao! * todasAreas.length;
    if (resultado.length < tetoGeral) {
      for (final p in _pontosLatLng) {
        if (resultado.length >= tetoGeral) break;
        if (vistos.add(p)) resultado.add(p);
      }
    }

    return resultado;
  }

  LatLngBounds? get _boundsGerais {
    final pontos = _pontosLatLng;
    if (pontos.isNotEmpty) return LatLngBounds.fromPoints(pontos);
    if (widget.areasCidades.isEmpty) return null;
    double? south, north, west, east;
    for (final a in widget.areasCidades.values) {
      south = south == null ? a.south : math.min(south, a.south);
      north = north == null ? a.north : math.max(north, a.north);
      west = west == null ? a.west : math.min(west, a.west);
      east = east == null ? a.east : math.max(east, a.east);
    }
    return LatLngBounds(LatLng(south!, west!), LatLng(north!, east!));
  }

  void _atualizarCamera(PointsRefinementMap oldWidget) {
    final mudouPontos = widget.features != oldWidget.features && widget.features.isNotEmpty;
    final mudouCidades = widget.areasCidades != oldWidget.areasCidades && widget.areasCidades.isNotEmpty;
    if ((mudouPontos || mudouCidades) && _areaIsolada == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final bounds = _boundsGerais;
        if (bounds == null) return;
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32), maxZoom: 16));
      });
    }
  }

  // -----------------------------------------------------------------------
  // Isolar (ou sair do isolamento) uma peça ao tocar no chip
  // -----------------------------------------------------------------------

  Future<void> _alternarIsolamento(Object id, SelectedArea area) async {
    if (_areaIsolada == id) {
      // Já estava isolada — toca de novo pra voltar a ver tudo.
      setState(() {
        _areaIsolada = null;
        _pulsoAceso = false;
      });
      final bounds = _boundsGerais;
      if (bounds != null) {
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32), maxZoom: 16));
      }
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(bounds: LatLngBounds(LatLng(area.south, area.west), LatLng(area.north, area.east)), padding: const EdgeInsets.all(32), maxZoom: 16),
    );
    setState(() => _areaIsolada = id);
    // Pisca duas vezes na entrada, pra dar um "pop" visual, e fica
    // aceso enquanto continuar isolada.
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      setState(() => _pulsoAceso = true);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _pulsoAceso = false);
      await Future.delayed(const Duration(milliseconds: 140));
    }
    if (mounted) setState(() => _pulsoAceso = true);
  }

  SelectedArea? _areaDoPoligono(Map<String, dynamic> polygon) {
    final cantos = _corners(polygon);
    if (cantos == null || cantos.isEmpty) return null;
    double? south, north, west, east;
    for (final p in cantos) {
      south = south == null ? p.latitude : math.min(south, p.latitude);
      north = north == null ? p.latitude : math.max(north, p.latitude);
      west = west == null ? p.longitude : math.min(west, p.longitude);
      east = east == null ? p.longitude : math.max(east, p.longitude);
    }
    return SelectedArea(south: south!, north: north!, west: west!, east: east!, diagonalKm: 0);
  }

  // -----------------------------------------------------------------------
  // Desenho manual das áreas de monitoramento
  // -----------------------------------------------------------------------

  void _onPanStart(DragStartDetails d) {
    if (!_desenhandoManualmente) return;
    setState(() {
      _dragStartOffset = d.localPosition;
      _dragCurrentOffset = d.localPosition;
      _retanguloPendente = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null) return;
    setState(() => _dragCurrentOffset = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null || _dragCurrentOffset == null) return;
    setState(() {
      _retanguloPendente = Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!);
      _dragStartOffset = null;
      _dragCurrentOffset = null;
    });
  }

  /// A área de monitoramento precisa TOCAR pelo menos uma das cidades
  /// selecionadas — não dá pra desenhar completamente fora delas.
  bool _tocaAlgumaCidade(double south, double north, double west, double east) {
    if (widget.areasCidades.isEmpty) return true;
    for (final a in widget.areasCidades.values) {
      final toca = !(east < a.west || west > a.east || north < a.south || south > a.north);
      if (toca) return true;
    }
    return false;
  }

  void _confirmarRetangulo() {
    final rect = _retanguloPendente;
    if (rect == null) return;

    final camera = _mapController.camera;
    final p1 = camera.offsetToCrs(rect.topLeft);
    final p2 = camera.offsetToCrs(rect.bottomRight);

    final south = math.min(p1.latitude, p2.latitude);
    final north = math.max(p1.latitude, p2.latitude);
    final west = math.min(p1.longitude, p2.longitude);
    final east = math.max(p1.longitude, p2.longitude);

    setState(() => _retanguloPendente = null);

    if (!_tocaAlgumaCidade(south, north, west, east)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Essa área está fora das cidades selecionadas — desenhe dentro de um dos retângulos azuis.')));
      return;
    }

    // GeoJSON usa [longitude, latitude], anel fechado (primeiro ==
    // último ponto).
    final polygonGeojson = {
      'type': 'Polygon',
      'coordinates': [
        [
          [west, north],
          [east, north],
          [east, south],
          [west, south],
          [west, north],
        ],
      ],
    };

    // Não desliga o modo desenho — deixa desenhar a próxima área de
    // monitoramento direto, sem precisar tocar no botão de novo.
    widget.onAreasMonitoramentoChanged?.call([...widget.areasMonitoramento, polygonGeojson]);
  }

  void _descartarRetangulo() => setState(() => _retanguloPendente = null);

  void _removerArea(int indice) {
    final removida = widget.areasMonitoramento[indice];
    final nova = [...widget.areasMonitoramento]..removeAt(indice);
    if (_areaIsolada == removida) _areaIsolada = null;
    widget.onAreasMonitoramentoChanged?.call(nova);
  }

  List<LatLng>? _corners(Map<String, dynamic> polygon) {
    try {
      final ring = (polygon['coordinates'] as List)[0] as List;
      return ring.map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _escolherLimite() async {
    // Usa o total OFICIAL do banco (mandado pelo pai), não a
    // contagem local de pontos já parseados — evita qualquer
    // possibilidade dos dois divergirem.
    final total = widget.totalPontosBanco ?? _pontosLatLng.length;

    // "Todos" e "fechar sem escolher" (tocar fora) normalmente
    // pareceriam a mesma coisa (os dois voltam null) — usa -1 como
    // sinal só pra "Todos", deixando o null de verdade exclusivo
    // pra "fechou sem escolher nada".
    const sentinelaTodos = -1;
    final escolhaSentinela = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _opcoesLimite.map((opcao) {
              final label = opcao == null ? 'Todos ($total)' : '$opcao por área';
              return ListTile(
                title: Text(label),
                trailing: _limiteRenderizacao == opcao ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, opcao ?? sentinelaTodos),
              );
            }).toList(),
          ),
        );
      },
    );

    // Tocou fora do modal sem escolher nada — só fecha, sem abrir
    // outro modal por cima.
    if (escolhaSentinela == null) return;

    final escolha = escolhaSentinela == sentinelaTodos ? null : escolhaSentinela;
    if (escolha == _limiteRenderizacao) return;
    if (escolha == null && total > 500) {
      if (!mounted) return;
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mostrar todos os pontos?'),
          content: Text('São $total pontos — o mapa pode ficar lento pra interagir. Quer continuar mesmo assim?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mostrar todos')),
          ],
        ),
      );
      if (confirmou != true) return;
    }
    setState(() => _limiteRenderizacao = escolha);
  }

  @override
  Widget build(BuildContext context) {
    final pontosTotal = _pontosLatLng;
    final pontosDesenhados = _pontosParaDesenhar;
    final liveRect = (_dragStartOffset != null && _dragCurrentOffset != null)
        ? Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!)
        : null;
    final bounds = _boundsGerais;
    final isolada = _areaIsolada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                () {
                  final totalOficial = widget.totalPontosBanco ?? pontosTotal.length;
                  return totalOficial > pontosDesenhados.length
                      ? 'Mostrando ${pontosDesenhados.length} de $totalOficial pontos'
                      : '$totalOficial ponto(s)';
                }(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _escolherLimite,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_limiteRenderizacao == null ? 'Todos' : '${_limiteRenderizacao!} pts/área', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (widget.permitirDesenho)
              InkWell(
                onTap: () => setState(() => _desenhandoManualmente = !_desenhandoManualmente),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _desenhandoManualmente ? Colors.deepOrange : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_desenhandoManualmente ? Icons.stop_circle_outlined : Icons.draw_outlined,
                          size: 14, color: _desenhandoManualmente ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(_desenhandoManualmente ? 'Parar' : 'Desenhar área',
                          style: TextStyle(fontSize: 12, color: _desenhandoManualmente ? Colors.white : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (widget.areasCidades.isNotEmpty || widget.areasMonitoramento.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...widget.areasCidades.entries.map((e) {
                  final contagemExata = widget.contagensCidades[e.key];
                  final selecionada = isolada == e.key;
                  final podeRemover = widget.areasCidades.length > 1 && widget.onRemoverCidade != null;
                  return Tooltip(
                    message: contagemExata != null ? 'Contagem exata do banco.' : 'Calculando a contagem exata...',
                    child: GestureDetector(
                      onTap: () => _alternarIsolamento(e.key, e.value),
                      child: Chip(
                        avatar: Icon(Icons.location_city, size: 14, color: selecionada ? Colors.white : AppColors.infoBlue),
                        label: Text(
                            contagemExata != null ? '${e.key.rotulo} ($contagemExata)' : '${e.key.rotulo} (...)',
                            style: TextStyle(fontSize: 12, color: selecionada ? Colors.white : null, fontWeight: selecionada ? FontWeight.w700 : null)),
                        backgroundColor: selecionada ? AppColors.infoBlue : AppColors.infoBlueBg,
                        side: selecionada ? const BorderSide(color: AppColors.infoBlue, width: 1.5) : null,
                        onDeleted: podeRemover ? () => widget.onRemoverCidade!(e.key) : null,
                        deleteIconColor: selecionada ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
                ...widget.areasMonitoramento.asMap().entries.map((e) {
                  final area = _areaDoPoligono(e.value);
                  final contagemExata = widget.contagensAreas[e.value];
                  final selecionada = isolada == e.value;
                  return Tooltip(
                    message: contagemExata != null ? 'Contagem exata do banco.' : 'Calculando a contagem exata...',
                    child: GestureDetector(
                      onTap: area == null ? null : () => _alternarIsolamento(e.value, area),
                      child: Chip(
                        avatar: Icon(Icons.crop_square, size: 14, color: selecionada ? Colors.white : Colors.deepOrange),
                        label: Text(contagemExata != null ? 'Área ${e.key + 1} ($contagemExata)' : 'Área ${e.key + 1} (...)',
                            style: TextStyle(fontSize: 12, color: selecionada ? Colors.white : null, fontWeight: selecionada ? FontWeight.w700 : null)),
                        onDeleted: () => _removerArea(e.key),
                        backgroundColor: selecionada ? Colors.deepOrange : AppColors.chipBg,
                        deleteIconColor: selecionada ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        if (_desenhandoManualmente)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('Arraste dentro de um retângulo azul, confirme com ✓ — pode desenhar quantas áreas quiser.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 6),
        Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4E8EF))),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: bounds?.center ?? const LatLng(-14.2350, -51.9253),
                  initialZoom: bounds != null ? 12 : 4,
                  initialCameraFit: bounds != null ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32), maxZoom: 16) : null,
                  minZoom: 3,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.tecsys.app',
                  ),
                  if (_mostrarRelevoNasa)
                    Opacity(
                      opacity: _opacidadeRelevo,
                      child: TileLayer(
                        urlTemplate:
                            'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/ASTER_GDEM_Greyscale_Shaded_Relief/default/GoogleMapsCompatible_Level12/{z}/{y}/{x}.png',
                        tileProvider: NetworkTileProvider(),
                        maxNativeZoom: 12,
                        maxZoom: 22,
                      ),
                    ),
                  // Cidades — some da tela quando outra peça está
                  // isolada (só a isolada aparece).
                  PolygonLayer(
                    polygons: widget.areasCidades.entries.where((e) => isolada == null || isolada == e.key).map((e) {
                      final aceso = isolada == e.key && _pulsoAceso;
                      return Polygon(
                        points: e.value.corners,
                        color: aceso ? AppColors.infoBlue.withOpacity(0.45) : AppColors.infoBlue.withOpacity(0.08),
                        borderColor: AppColors.infoBlue,
                        borderStrokeWidth: aceso ? 4 : 1.5,
                      );
                    }).toList(),
                  ),
                  CircleLayer(
                    circles: pontosDesenhados
                        .map((p) => CircleMarker(point: p, radius: 5, color: AppColors.primary, borderColor: Colors.white, borderStrokeWidth: 1.5))
                        .toList(),
                  ),
                  PolygonLayer(
                    polygons: widget.areasMonitoramento.where((polygon) => isolada == null || isolada == polygon).map((polygon) {
                      final cantos = _corners(polygon);
                      if (cantos == null) return null;
                      final aceso = isolada == polygon && _pulsoAceso;
                      return Polygon(
                        points: cantos,
                        color: aceso ? Colors.deepOrange.withOpacity(0.45) : Colors.deepOrange.withOpacity(0.25),
                        borderColor: Colors.deepOrange,
                        borderStrokeWidth: aceso ? 3 : 2,
                      );
                    }).whereType<Polygon>().toList(),
                  ),
                ],
              ),

              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_desenhandoManualmente,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              if (liveRect != null)
                Positioned.fromRect(
                  rect: liveRect,
                  child: Container(decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.25), border: Border.all(color: Colors.deepOrange, width: 2))),
                ),

              if (_retanguloPendente != null) ...[
                Positioned.fromRect(
                  rect: _retanguloPendente!,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.35), border: Border.all(color: Colors.deepOrange, width: 2)),
                  ),
                ),
                Positioned(
                  left: _retanguloPendente!.center.dx - 40,
                  top: _retanguloPendente!.center.dy - 18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _botaoConfirmacao(Icons.check, Colors.green, _confirmarRetangulo, tooltip: 'Confirmar área'),
                      const SizedBox(width: 8),
                      _botaoConfirmacao(Icons.close, Colors.redAccent, _descartarRetangulo, tooltip: 'Descartar'),
                    ],
                  ),
                ),
              ],

              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    _botaoMapa(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                    const SizedBox(height: 6),
                    _botaoMapa(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                    if (widget.mostrarToggleRelevo) ...[
                      const SizedBox(height: 6),
                      _botaoMapa(Icons.terrain, () => setState(() => _mostrarPainelCamadas = !_mostrarPainelCamadas)),
                    ],
                  ],
                ),
              ),

              if (widget.mostrarToggleRelevo && _mostrarPainelCamadas)
                Positioned(
                  top: 8,
                  right: 52,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Relevo NASA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Switch(value: _mostrarRelevoNasa, onChanged: (v) => setState(() => _mostrarRelevoNasa = v)),
                            ],
                          ),
                          if (_mostrarRelevoNasa)
                            SizedBox(
                              width: 140,
                              child: Slider(value: _opacidadeRelevo, min: 0.1, max: 1.0, divisions: 9, onChanged: (v) => setState(() => _opacidadeRelevo = v)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botaoMapa(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _botaoConfirmacao(IconData icon, Color color, VoidCallback onTap, {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}