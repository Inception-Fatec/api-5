import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../services/ibge_service.dart';
import '../services/points_filter_service.dart';
import '../services/project_service.dart';
import '../services/project_store.dart';
import '../utils/normalizar_texto.dart';
import '../widgets/map/points_map_view.dart';
import '../widgets/map/filtros_pontos.dart';
import '../widgets/filters/filter_dropdown_bar.dart';

class PointsMapScreen extends StatefulWidget {
  const PointsMapScreen({
    super.key,
    required this.nomeProjeto,
    required this.distCode,
    required this.distribuidoraLabel,
    required this.municipios,
  });

  final String nomeProjeto;
  final String distCode;
  final String distribuidoraLabel;
  final List<Municipio> municipios;

  @override
  State<PointsMapScreen> createState() => _PointsMapScreenState();
}

class _PointsMapScreenState extends State<PointsMapScreen> {
  final GlobalKey<PointsMapViewState> _mapKey = GlobalKey<PointsMapViewState>();
  final _ibge = IbgeService();
  final _service = PointsFilterService();
  final _projectsService = ProjectsService();

  late List<Municipio> _municipiosSelecionados = List.of(widget.municipios);

  List<Municipio> _cidadesDisponiveis = [];

  List<String> _targetLayers = ['all']; // "Todos" já vem marcado por padrão
  List<String> _conjCodes = [];
  List<String> _subCodes = [];
  List<String> _clasSub = [];
  List<String> _cnaeCodes = [];
  List<String> _bairroNames = [];

  int? _totalPontos;
  bool _zoomBaixoDemais = false;

  bool _salvando = false;
  bool _projetoSalvo = false;
  int? _totalFinal;

  Timer? _debounceCentralizar;

  static const _targetLayerOptions = ['alto', 'medio', 'baixo', 'all'];

  static const _clasSubOptions = [
    'IN — Industrial',
    'CO1 — Comercial', 'CO4 — Comercial', 'CO5 — Comercial', 'CO6 — Comercial', 'CO8 — Comercial',
    'PP1 — Poder Público', 'PP2 — Poder Público', 'PP3 — Poder Público',
    'RU1 — Rural', 'RU2 — Rural', 'RU5 — Rural',
    'SP2 — Serviço Público',
    'IP', 'CPR',
  ];

  static const _codigoSJC = 3549904;
  static const _codigoCacapava = 3508504;
  static const _centroSJC = LatLng(-23.1896, -45.8841);
  static const _centroCacapava = LatLng(-23.0996, -45.7075);
  static const _centroEntreAsDuas = LatLng(-23.1446, -45.7958);

  static String _rotuloNivelTensao(String valor) => switch (valor) {
        'alto' => 'Alto',
        'medio' => 'Médio',
        'baixo' => 'Baixo',
        'all' => 'Todos',
        _ => valor,
      };

  List<String> get _subCodesNormalizados => _subCodes.map((v) => normalizarTexto(v).toUpperCase().trim()).toList();
  List<String> get _clasSubCodigos => _clasSub.map((v) => v.split(' — ').first).toList();
  List<String> get _bairroNormalizado => _bairroNames.map(normalizarTexto).map((v) => v.toUpperCase()).toList();

  FiltrosPontos get _filtrosAtuais => FiltrosPontos(
        distCode: widget.distCode,
        targetLayers: _targetLayers,
        conjCodes: _conjCodes,
        subCodes: _subCodesNormalizados,
        clasSub: _clasSubCodigos,
        cnaeCodes: _cnaeCodes,
        bairroNames: _bairroNormalizado,
      );

  (LatLng, double) get _centroEZoomIniciais {
    final codigos = widget.municipios.map((m) => m.codigoIbge).toSet();
    final temSJC = codigos.contains(_codigoSJC);
    final temCacapava = codigos.contains(_codigoCacapava);

    if (temSJC && temCacapava) {
      return (_centroEntreAsDuas, 18); 
    }
    if (temCacapava) {
      return (_centroCacapava, 18);
    }
    return (_centroSJC, 18);
  }

  @override
  void initState() {
    super.initState();
    _carregarCidadesDisponiveis();
  }

  @override
  void dispose() {
    _debounceCentralizar?.cancel();
    super.dispose();
  }

  Future<void> _carregarCidadesDisponiveis() async {
    try {
      final sjc = await _ibge.buscarPorNome('São José dos Campos');
      final cacapava = await _ibge.buscarPorNome('Caçapava');
      final cidades = <Municipio>[
        ...sjc.where((m) => m.uf == 'SP').take(1),
        ...cacapava.where((m) => m.uf == 'SP').take(1),
      ];
      if (!mounted) return;
      setState(() => _cidadesDisponiveis = cidades);
    } catch (_) {
    }
  }

  LatLng? _centroFixoDe(Municipio m) {
    if (m.codigoIbge == _codigoSJC) return _centroSJC;
    if (m.codigoIbge == _codigoCacapava) return _centroCacapava;
    return null;
  }

  void _aoMarcarCidade(Municipio m) {
    final jaSelecionada = _municipiosSelecionados.contains(m);
    if (jaSelecionada) {
      if (_municipiosSelecionados.length <= 1) return; // precisa de pelo menos 1
      setState(() => _municipiosSelecionados = _municipiosSelecionados.where((x) => x != m).toList());
      return;
    }
    setState(() => _municipiosSelecionados = [..._municipiosSelecionados, m]);

    final centro = _centroFixoDe(m);
    if (centro != null) {
      _mapKey.currentState?.mapController.move(centro, 18);
      _mapKey.currentState?.buscarNovamente();
    }
  }

  void _agendarCentralizacao() {
    _debounceCentralizar?.cancel();
    _debounceCentralizar = Timer(const Duration(milliseconds: 600), _centralizarEmFiltroAtual);
  }

  LatLng? _pontoDe(Map<String, dynamic>? geom) {
    if (geom == null) return null;
    final coords = geom['coordinates'];
    if (geom['type'] == 'Point' && coords is List && coords.length >= 2) {
      return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
    }
    var somaLat = 0.0, somaLon = 0.0, n = 0;
    void percorrer(dynamic v) {
      if (v is List && v.length >= 2 && v[0] is num && v[1] is num) {
        somaLon += (v[0] as num).toDouble();
        somaLat += (v[1] as num).toDouble();
        n++;
      } else if (v is List) {
        for (final e in v) {
          percorrer(e);
        }
      }
    }

    percorrer(coords);
    return n == 0 ? null : LatLng(somaLat / n, somaLon / n);
  }

  Future<void> _centralizarEmFiltroAtual() async {
    final filtros = _filtrosAtuais;
    final temFiltro = filtros.bairroNames.isNotEmpty ||
        filtros.conjCodes.isNotEmpty ||
        filtros.subCodes.isNotEmpty ||
        filtros.clasSub.isNotEmpty ||
        filtros.cnaeCodes.isNotEmpty ||
        (filtros.targetLayers.isNotEmpty && !filtros.targetLayers.contains('all'));

    if (!temFiltro) return;

    try {
      final resultado = await _service.buscarPontos(
        distCodes: [widget.distCode],
        munCodes: _municipiosSelecionados.map((m) => m.codigoIbge.toString()).toList(),
        targetLayers: filtros.targetLayers,
        conjCodes: filtros.conjCodes,
        subCodes: filtros.subCodes,
        clasSub: filtros.clasSub,
        cnaeCodes: filtros.cnaeCodes,
        bairroNames: filtros.bairroNames,
      );
      if (!mounted || resultado.features.isEmpty) return;

      final alvo = resultado.features.firstWhere(
        (f) => (f['geometry'] as Map<String, dynamic>?)?['type'] == 'Point',
        orElse: () => resultado.features.first,
      );
      final ponto = _pontoDe(alvo['geometry'] as Map<String, dynamic>?);
      if (ponto == null) return;
      _mapKey.currentState?.mapController.move(ponto, 17);
      _mapKey.currentState?.buscarNovamente();
    } catch (_) {
    }
  }

  Future<void> _salvarProjeto() async {
    if (widget.nomeProjeto.trim().isEmpty) return; 
    setState(() {
      _salvando = true;
      _projetoSalvo = false;
    });

    try {
      final filtros = _filtrosAtuais;
      final resultadoPontos = await _service.buscarPontos(
        distCodes: [widget.distCode],
        munCodes: _municipiosSelecionados.map((m) => m.codigoIbge.toString()).toList(),
        targetLayers: filtros.targetLayers,
        conjCodes: filtros.conjCodes,
        subCodes: filtros.subCodes,
        clasSub: filtros.clasSub,
        cnaeCodes: filtros.cnaeCodes,
        bairroNames: filtros.bairroNames,
      );

      final projetoCriado = await _projectsService.criar(
        name: widget.nomeProjeto,
        distCode: widget.distCode,
      );
      ProjectsStore.instance.adicionar(projetoCriado);

      if (!mounted) return;
      setState(() {
        _totalFinal = resultadoPontos.totalPoints;
        _projetoSalvo = true;
        _salvando = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Não foi possível salvar agora. Tente de novo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (centro, zoom) = _centroEZoomIniciais;

    return Scaffold(
      body: Stack(
        children: [
          PointsMapView(
            key: _mapKey,
            filtros: _filtrosAtuais,
            initialCenter: centro,
            initialZoom: zoom,
            onTotalChanged: (t) => setState(() => _totalPontos = t),
            onZoomMuitoBaixo: (b) => setState(() => _zoomBaixoDemais = b),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.sm),
                    child: IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: FilterDropdownBar(
                    distribuidoraLabel: widget.distribuidoraLabel,
                    cidadesDisponiveis: _cidadesDisponiveis,
                    cidadesSelecionadas: _municipiosSelecionados,
                    onCidadeMarcada: _aoMarcarCidade,
                    bairroNames: _bairroNames,
                    onBairroChanged: (v) {
                      setState(() => _bairroNames = List.of(v));
                      _agendarCentralizacao();
                    },
                    targetLayerOptions: _targetLayerOptions,
                    targetLayers: _targetLayers,
                    onTargetLayersChanged: (v) {
                      setState(() => _targetLayers = List.of(v));
                      _agendarCentralizacao();
                    },
                    rotuloNivelTensao: _rotuloNivelTensao,
                    conjCodes: _conjCodes,
                    onConjChanged: (v) {
                      setState(() => _conjCodes = List.of(v));
                      _agendarCentralizacao();
                    },
                    subCodes: _subCodes,
                    onSubChanged: (v) {
                      setState(() => _subCodes = List.of(v));
                      _agendarCentralizacao();
                    },
                    clasSubOptions: _clasSubOptions,
                    clasSub: _clasSub,
                    onClasSubChanged: (v) {
                      setState(() => _clasSub = List.of(v));
                      _agendarCentralizacao();
                    },
                    cnaeCodes: _cnaeCodes,
                    onCnaeChanged: (v) {
                      setState(() => _cnaeCodes = List.of(v));
                      _agendarCentralizacao();
                    },
                    totalPontos: _totalPontos,
                  ),
                ),
              ],
            ),
          ),
          if (_zoomBaixoDemais)
            Positioned(
              bottom: 90,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Dá mais zoom pra ver os pontos dessa área.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvarProjeto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _projetoSalvo ? AppColors.success : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _salvando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_projetoSalvo ? Icons.check_circle_outline : Icons.save_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _projetoSalvo
                                      ? 'Salvo — ${_totalFinal ?? 0} ponto(s)'
                                      : 'Salvar Projeto',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}