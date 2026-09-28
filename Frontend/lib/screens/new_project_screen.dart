import 'dart:async';

import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../services/project_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common/page_body.dart';
import '../widgets/map/points_refinement_map.dart';
import '../widgets/map/selected_area.dart';
import '../services/points_filter_service.dart';
import '../services/geocoding_service.dart';
import '../services/ibge_service.dart';
import '../utils/normalizar_texto.dart';
import '../app_shell.dart';

/// "New Project" screen — fluxo oficial em 2 etapas:
///
///   ETAPA 1 (obrigatória): Empresa/Distribuidora + Município(s).
///   Dispara a busca real no backend (`POST /api/v1/points/filter`
///   só com dist_codes + mun_codes). Sem resultado → avisa e NÃO
///   libera a etapa 2 (RN02). Com resultado → mostra o mapa com os
///   pontos de verdade.
///
///   ETAPA 2 (só aparece com dados): mapa com os pontos + refinamento
///   espacial por UM polígono desenhado (RN04 — filtra dentro do que
///   já foi carregado, não define área do zero), níveis de tensão
///   (alto/medio/baixo/all — RN03), e os demais filtros opcionais.
///   Botão final "Salvar Projeto" reenvia tudo consolidado.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _nomeProjetoController = TextEditingController();
  // Etapa 1 — voltou a ser dropdown: o backend guarda o CÓDIGO da
  // distribuidora na coluna dist (confirmado: "391"), não o nome por
  // extenso — texto livre não bate com isso.
  String _distCode = '391';

  static const _distribuidoras = {
    '391': 'EDP São Paulo',
    // TODO: popular dinamicamente quando existir um endpoint de
    // distribuidoras/concessionárias no backend.
  };
  final _service = PointsFilterService();
  final _geocoding = GeocodingService();
  final _projectsService = ProjectsService();

  // Índice da aba "Projects" no AppShell (Projects=0, New Project=1, Map=2)
  // — pra onde a gente manda o usuário depois de salvar com sucesso.
  static const _projectsTabIndex = 0;

  // Etapa 1
  final List<Municipio> _municipios = [];
  bool _buscandoEtapa1 = false;
  String? _erroEtapa1;
  String? _avisoEtapa1; // informativo, não bloqueia (ex: backend indisponível)
  List<Map<String, dynamic>> _features = [];
  int? _totalEtapa1;

  // Área combinada das cidades (geocoding, client-side) — é isso que
  // decide se a Etapa 2 aparece, já que hoje o backend ainda não
  // existe pra confirmar pontos reais. Quando o endpoint existir de
  // verdade, os pontos (_features) vêm junto e são plotados por cima
  // dessa mesma área.
  Map<Municipio, SelectedArea> _areasCidades = {};

  // Contagem EXATA (vinda do backend, count_only) por cidade/área —
  // substitui a estimativa por retângulo aproximado que o mapa fazia
  // sozinho antes. null enquanto ainda não veio a resposta (o mapa
  // usa a estimativa como placeholder só até isso chegar).
  Map<Municipio, int> _contagensCidades = {};
  Map<Map<String, dynamic>, int> _contagensAreas = {};

  // Etapa 2 — só relevante depois de ter pontos carregados
  List<Map<String, dynamic>> _areasMonitoramento = [];
  final List<String> _conjCodes = [];
  final List<String> _subCodes = [];
  List<String> _targetLayers = [];
  final List<String> _clasSub = [];
  final List<String> _cnaeCodes = [];
  final List<String> _bairroNames = [];

  bool _salvando = false;
  bool _projetoSalvo = false;
  bool _aplicandoFiltros = false;
  int? _totalFinal;

  static const _targetLayerOptions = ['alto', 'medio', 'baixo', 'all'];

  static String _rotuloNivelTensao(String valor) => switch (valor) {
        'alto' => 'Alto',
        'medio' => 'Médio',
        'baixo' => 'Baixo',
        'all' => 'Todos',
        _ => valor,
      };

  // TODO: valores de exemplo — confirmar com o dicionário oficial de
  // CLAS_SUB da BDGD antes de fechar essa lista.
  // Códigos reais confirmados direto no banco (SELECT DISTINCT
  // clas_sub) — bem diferentes do que a gente tinha chutado antes
  // (nomes bonitos que não existem de verdade na coluna). Os
  // prefixos CO/PP/RU/SP batem com o dicionário que o cliente já
  // tinha passado (Grupo B: IN=Industrial, CO*=Comercial,
  // RU*=Rural, PP*=Poder Público, SP*=Serviço Público); IP e CPR
  // não têm significado confirmado ainda — ficam como código puro.
  static const _clasSubOptions = [
    'IN — Industrial',
    'CO1 — Comercial', 'CO4 — Comercial', 'CO5 — Comercial', 'CO6 — Comercial', 'CO8 — Comercial',
    'PP1 — Poder Público', 'PP2 — Poder Público', 'PP3 — Poder Público',
    'RU1 — Rural', 'RU2 — Rural', 'RU5 — Rural',
    'SP2 — Serviço Público',
    'IP', 'CPR',
  ];

  @override
  void dispose() {
    _debounceFiltro?.cancel();
    _nomeProjetoController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Etapa 1 — busca inicial (RN01, RN02)
  // -----------------------------------------------------------------------

  // Cache simples da Etapa 1 — evita bater no backend de novo (e
  // reprocessar dezenas de milhares de pontos) se você buscar
  // exatamente a mesma combinação de empresa+cidades outra vez.
  final Map<String, PointsFilterResult> _cacheEtapa1 = {};

  // Cache do geocoding por cidade — a área de uma cidade não muda,
  // então não faz sentido perguntar pro Nominatim nem uma segunda
  // vez. Isso sozinho já era boa parte da demora de "buscar de novo".
  final Map<Municipio, SelectedArea> _cacheGeocoding = {};

  String _chaveCache(String dist, List<Municipio> municipios) {
    final codigos = municipios.map((m) => m.codigoIbge).toList()..sort();
    return '$dist|${codigos.join(",")}';
  }

  // Subestação também está gravada em maiúsculo no banco (igual
  // bairro) — sem isso, "sjc" digitado minúsculo não bate com "SJC"
  // (Postgres compara texto de forma sensível a maiúscula/minúscula
  // por padrão).
  List<String> get _subCodesNormalizados => _subCodes.map((v) => normalizarTexto(v).toUpperCase().trim()).toList();

  Future<void> _buscarEtapa1() async {
    final empresa = _distCode;

    if (empresa.isEmpty || _municipios.isEmpty) {
      setState(() => _erroEtapa1 = 'Informe a Empresa/Distribuidora e ao menos um Município.');
      return;
    }

    setState(() {
      _buscandoEtapa1 = true;
      _erroEtapa1 = null;
      _avisoEtapa1 = null;
    });

    // 1) Geocoding das cidades escolhidas — só busca de verdade a
    // primeira vez; da segunda em diante, reaproveita o cache. Não
    // depende do backend. É isso que garante o mapa aparecer.
    // Cada cidade guarda a PRÓPRIA área (não combina mais tudo num
    // retângulo só).
    final novasAreas = <Municipio, SelectedArea>{};
    for (final m in _municipios) {
      final cacheada = _cacheGeocoding[m];
      if (cacheada != null) {
        novasAreas[m] = cacheada;
        continue;
      }
      final resultados = await _geocoding.buscar('${m.nome}, ${m.uf}, Brasil');
      if (resultados.isEmpty) continue;
      novasAreas[m] = resultados.first.area;
      _cacheGeocoding[m] = resultados.first.area;
    }

    if (!mounted) return;

    if (novasAreas.isEmpty) {
      setState(() {
        _buscandoEtapa1 = false;
        _erroEtapa1 = 'Não foi possível localizar a(s) cidade(s) escolhida(s) no mapa.';
      });
      return;
    }

    setState(() {
      _areasCidades = novasAreas;
      // Busca nova — reseta o que a etapa 2 já tinha.
      _areasMonitoramento = [];
      _totalFinal = null;
      _features = [];
      _totalEtapa1 = null;
      _contagensCidades = {};
      _contagensAreas = {};
    });

    // 2) Tenta o backend de verdade, por trás — se ele ainda não
    // existir/responder, não trava a tela: o mapa já apareceu com a
    // área geocodificada no passo 1. Assim que o endpoint existir,
    // isso passa a preencher pontos reais automaticamente, sem
    // precisar mudar mais nada aqui.
    final chave = _chaveCache(empresa, _municipios);
    final doCache = _cacheEtapa1[chave];
    if (doCache != null) {
      setState(() {
        _totalEtapa1 = doCache.totalPoints;
        _features = doCache.features;
        _buscandoEtapa1 = false;
      });
      // Sem isso, os chips de cidade ficavam esperando pra sempre um
      // filtro mudar — a contagem por cidade nunca rodava sozinha
      // logo depois da busca inicial.
      _atualizarContagensPorPeca(++_pedidoFiltroId);
      return;
    }

    try {
      final resultado = await _service.buscarPontos(
        distCodes: [empresa],
        munCodes: _municipios.map((m) => m.codigoIbge.toString()).toList(),
      );
      if (!mounted) return;
      _cacheEtapa1[chave] = resultado;
      setState(() {
        _totalEtapa1 = resultado.totalPoints;
        _features = resultado.features;
        _buscandoEtapa1 = false;
        if (resultado.totalPoints == 0) {
          _avisoEtapa1 = 'Backend não retornou pontos ainda (endpoint em desenvolvimento) — mostrando a área pela cidade.';
        }
      });
      _atualizarContagensPorPeca(++_pedidoFiltroId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buscandoEtapa1 = false;
        _avisoEtapa1 = 'Backend ainda não disponível — mostrando a área pela cidade, sem pontos reais por enquanto.';
      });
    }
  }

  // -----------------------------------------------------------------------
  // Filtros de Grupo B (Conjunto, Subestação, Classe/Subclasse, CNAE,
  // Bairro) — ao contrário de nível de tensão, o app não sabe de
  // qual conjunto/subestação/classe/CNAE/bairro é cada ponto só
  // olhando os dados que já tem (o GeoJSON não carrega isso por
  // ponto), então precisa perguntar pro backend de novo toda vez que
  // um desses muda. Atualiza o mapa sozinho, sem precisar de botão.
  // -----------------------------------------------------------------------

  int _pedidoFiltroId = 0;

  // Espera um instante depois da ÚLTIMA mudança de filtro antes de
  // perguntar pro backend — sem isso, preencher vários campos rápido
  // (ex: CNAE e Bairro em seguida) disparava uma busca por campo, e
  // cada uma cancelava a anterior antes dela terminar, deixando os
  // chips presos num valor de um filtro incompleto no meio do
  // caminho. Com o debounce, só a combinação final (depois que você
  // para de mexer) realmente vai pro backend.
  Timer? _debounceFiltro;

  void _agendarAtualizacaoFiltros() {
    _debounceFiltro?.cancel();
    _debounceFiltro = Timer(const Duration(milliseconds: 500), _atualizarPontosComFiltros);
  }

  Future<void> _atualizarPontosComFiltros() async {
    final meuPedido = ++_pedidoFiltroId;
    setState(() {
      _aplicandoFiltros = true;
      // Qualquer filtro mudando invalida o resultado do último
      // "Salvar Projeto" — sem isso, aquele número ficava parado na
      // tela parecendo atual mesmo depois de mudar os filtros.
      _totalFinal = null;
      _projetoSalvo = false;
    });

    try {
      final poligono = _montarMultiPolygon();
      final resultado = await _service.buscarPontos(
        distCodes: [_distCode],
        munCodes: poligono == null ? _municipios.map((m) => m.codigoIbge.toString()).toList() : const [],
        conjCodes: _conjCodes,
        subCodes: _subCodesNormalizados,
        polygonGeoJson: poligono,
        targetLayers: _targetLayers,
        clasSub: _clasSub.map((v) => v.split(' — ').first).toList(),
        cnaeCodes: _cnaeCodes,
        bairroNames: _bairroNames.map(normalizarTexto).map((v) => v.toUpperCase()).toList(),
      );
      // Se, enquanto esperava essa resposta, outro filtro já mudou de
      // novo, essa resposta está desatualizada — descarta.
      if (!mounted || meuPedido != _pedidoFiltroId) return;
      setState(() {
        _features = resultado.features;
        _totalEtapa1 = resultado.totalPoints;
        _aplicandoFiltros = false;
      });
      // Contagem exata por cidade/área, pros chips do mapa — roda
      // depois da principal, não trava a atualização do mapa em si
      // esperando isso (são N chamadas extras, uma por peça).
      _atualizarContagensPorPeca(meuPedido);
    } catch (_) {
      if (!mounted || meuPedido != _pedidoFiltroId) return;
      setState(() => _aplicandoFiltros = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Não foi possível atualizar os pontos com esses filtros agora.')));
    }
  }

  /// Contagem EXATA por peça (cada cidade **e** cada área desenhada,
  /// sempre as duas, mesmo que só uma delas seja a que realmente vale
  /// pro envio final — Grupo A continua mutuamente excludente pro
  /// que é ENVIADO, mas os chips mostram tudo com filtro aplicado,
  /// mesmo o que não está sendo usado no momento). Uma chamada
  /// `count_only` por peça, com os MESMOS filtros de Grupo B já
  /// aplicados — TODAS em paralelo (Future.wait), não uma atrás da
  /// outra. Sequencial era lento demais: se você preenche vários
  /// campos rápido, cada mudança cancela a busca anterior (pra não
  /// mostrar dado desatualizado) — e uma busca sequencial por várias
  /// cidades quase nunca tinha tempo de terminar antes do próximo
  /// campo chegar, deixando o chip preso num valor antigo pra sempre.
  Future<void> _atualizarContagensPorPeca(int meuPedido) async {
    final resultadosAreas = await Future.wait(_areasMonitoramento.map((area) async {
      try {
        final r = await _service.buscarPontos(
          distCodes: [_distCode],
          polygonGeoJson: area,
          conjCodes: _conjCodes,
          subCodes: _subCodesNormalizados,
          targetLayers: _targetLayers,
          clasSub: _clasSub.map((v) => v.split(' — ').first).toList(),
          cnaeCodes: _cnaeCodes,
          bairroNames: _bairroNames.map(normalizarTexto).map((v) => v.toUpperCase()).toList(),
          countOnly: true,
        );
        return MapEntry(area, r.totalPoints);
      } catch (_) {
        // Uma peça falhando não derruba as outras — só fica sem
        // número exato pra essa (o chip cai de volta pra "...").
        return null;
      }
    }));
    if (meuPedido != _pedidoFiltroId) return; // desatualizado, descarta
    final novasContagensAreas = <Map<String, dynamic>, int>{
      for (final e in resultadosAreas)
        if (e != null) e.key: e.value,
    };
    if (mounted) setState(() => _contagensAreas = novasContagensAreas);

    final resultadosCidades = await Future.wait(_municipios.map((m) async {
      try {
        final r = await _service.buscarPontos(
          distCodes: [_distCode],
          munCodes: [m.codigoIbge.toString()],
          conjCodes: _conjCodes,
          subCodes: _subCodesNormalizados,
          targetLayers: _targetLayers,
          clasSub: _clasSub.map((v) => v.split(' — ').first).toList(),
          cnaeCodes: _cnaeCodes,
          bairroNames: _bairroNames.map(normalizarTexto).map((v) => v.toUpperCase()).toList(),
          countOnly: true,
        );
        return MapEntry(m, r.totalPoints);
      } catch (_) {
        return null;
      }
    }));
    if (meuPedido != _pedidoFiltroId) return;
    final novasContagensCidades = <Municipio, int>{
      for (final e in resultadosCidades)
        if (e != null) e.key: e.value,
    };
    if (mounted) setState(() => _contagensCidades = novasContagensCidades);
  }

  // -----------------------------------------------------------------------
  // Etapa 2 — "Salvar Projeto": persiste o projeto de verdade via
  // POST /api/v1/projects (CRUD Java já existente — ProjectController/
  // ProjectService/ProjectRepository), usando o mesmo total já
  // calculado ao vivo pelos filtros pra exibir o resultado. Os
  // pontos/filtros da Etapa 2 (município, polígono, níveis de tensão
  // etc.) ainda NÃO são enviados nem persistidos — hoje o Project só
  // guarda nome + distribuidora; isso fica pra quando existir onde
  // guardar esses critérios no backend.
  // -----------------------------------------------------------------------
  Future<void> _salvarProjeto() async {
    final nomeProjeto = _nomeProjetoController.text.trim();
    if (nomeProjeto.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Preenche o Nome do Projeto antes de salvar.')));
      return;
    }

    setState(() => _salvando = true);

    // Se ainda não tem um total calculado com os filtros atuais
    // (ex: primeira vez, ou algum filtro mudou e a atualização ainda
    // não terminou), calcula agora antes de "salvar".
    if (_totalEtapa1 == null || _aplicandoFiltros) {
      await _atualizarPontosComFiltros();
      if (!mounted) return;
    }

    if (_totalEtapa1 == null) {
      // A atualização falhou (sem conexão, etc) — já mostrou o aviso
      // lá dentro; aqui só não segue pra "salvar" sem um total real.
      setState(() => _salvando = false);
      return;
    }

    try {
      final novoProjeto = await _projectsService.criar(name: nomeProjeto, distCode: _distCode);
      if (!mounted) return;
      // Entra na lista compartilhada AGORA — a ProjectsScreen mostra
      // ele na hora, mesmo que já esteja montada e não vá refazer o
      // GET sozinha ao trocar de aba.
      ProjectsStore.instance.adicionar(novoProjeto);
      // Volta pro estado inicial — como o AppShell mantém essa tela
      // viva ao trocar de aba, sem isso o próximo "New Project"
      // abriria com a busca/filtros do projeto anterior ainda lá.
      setState(_resetFormulario);
      // Projeto criado de verdade — manda o usuário pro card dele na
      // tela de Projetos.
      AppShell.of(context)?.goToTab(_projectsTabIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Não foi possível salvar o projeto agora. Tente de novo em instantes.')));
    }
  }

  /// Volta a tela inteira ao estado inicial — Etapa 1 e Etapa 2 —
  /// depois de um "Salvar Projeto" bem-sucedido. Chamar dentro de um
  /// setState; não chama setState sozinho.
  void _resetFormulario() {
    _debounceFiltro?.cancel();

    _nomeProjetoController.clear();
    _distCode = '391';

    _municipios.clear();
    _buscandoEtapa1 = false;
    _erroEtapa1 = null;
    _avisoEtapa1 = null;
    _features = [];
    _totalEtapa1 = null;

    _areasCidades = {};
    _contagensCidades = {};
    _contagensAreas = {};

    _areasMonitoramento = [];
    _conjCodes.clear();
    _subCodes.clear();
    _targetLayers = [];
    _clasSub.clear();
    _cnaeCodes.clear();
    _bairroNames.clear();

    _salvando = false;
    _projetoSalvo = false;
    _aplicandoFiltros = false;
    _totalFinal = null;
  }

  /// Combina as áreas de monitoramento desenhadas (0, 1 ou várias) num
  /// único GeoJSON — `MultiPolygon` quando existe mais de uma, pra
  /// mandar tudo numa única chamada de `polygon_geojson`. O PostGIS
  /// aceita `ST_Intersects`/`ST_Within` normalmente contra um
  /// MultiPolygon, então não precisa de tratamento especial no
  /// backend. Vazio = null (busca nas cidades inteiras).
  Map<String, dynamic>? _montarMultiPolygon() {
    if (_areasMonitoramento.isEmpty) return null;
    if (_areasMonitoramento.length == 1) return _areasMonitoramento.first;

    final coordinates = _areasMonitoramento.map((p) => (p['coordinates'] as List)).toList();
    return {'type': 'MultiPolygon', 'coordinates': coordinates};
  }

  @override
  Widget build(BuildContext context) {
    final mostrarEtapa2 = _areasCidades.isNotEmpty;

    return PageBody(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildTopo(),
          const SizedBox(height: AppSpacing.xl),

          // --- Etapa 1 ---------------------------------------------------
          _sectionLabel('Etapa 1 — Empresa e Município(s) *'),
          const SizedBox(height: AppSpacing.sm),
          _fieldLabel('Empresa / Distribuidora *'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _distCode,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                items: _distribuidoras.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})'))).toList(),
                onChanged: (v) => setState(() => _distCode = v!),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldLabel('Município(s) *'),
          _MunicipioMultiSelectField(
            selecionados: _municipios,
            distCode: _distCode,
            onChanged: (c) => setState(() { _municipios..clear()..addAll(c); }),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (_erroEtapa1 != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_erroEtapa1!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
            ),
          if (_avisoEtapa1 != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_avisoEtapa1!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _buscandoEtapa1 ? null : _buscarEtapa1,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _buscandoEtapa1
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 18),
                        SizedBox(width: 8),
                        Text('Buscar Pontos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),

          // --- Etapa 2 -----------------------------------------------------
          if (mostrarEtapa2) ...[
            const SizedBox(height: AppSpacing.xl),
            _sectionLabel('Etapa 2 — Refinamento'),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Sem desenhar nada, a busca considera a(s) cidade(s) inteira(s). '
              'Desenhe uma ou mais áreas no mapa pra restringir a busca só a elas.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_aplicandoFiltros)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Atualizando pontos com os filtros...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            PointsRefinementMap(
              areasCidades: _areasCidades,
              contagensCidades: _contagensCidades,
              contagensAreas: _contagensAreas,
              totalPontosBanco: _totalEtapa1,
              onRemoverCidade: (m) {
                setState(() {
                  _municipios.remove(m);
                  _areasCidades = Map.of(_areasCidades)..remove(m);
                  _contagensCidades = Map.of(_contagensCidades)..remove(m);
                });
                // Sem isso, o total geral ficava parado com o valor
                // de quando a cidade removida ainda estava incluída.
                _agendarAtualizacaoFiltros();
              },
              features: _features,
              areasMonitoramento: _areasMonitoramento,
              onAreasMonitoramentoChanged: (areas) {
                setState(() => _areasMonitoramento = areas);
                _agendarAtualizacaoFiltros();
              },
              targetLayers: _targetLayers,
              permitirDesenho: true,
              height: MediaQuery.of(context).size.width >= 900 ? 560 : 360,
            ),
            const SizedBox(height: AppSpacing.lg),
            _fieldLabel('Nível de Tensão'),
            _MultiSelectSheetField(
              label: 'Alto / Médio / Baixo / Todos',
              options: _targetLayerOptions,
              selected: _targetLayers,
              onChanged: (v) {
                setState(() => _targetLayers = List<String>.from(v));
                _agendarAtualizacaoFiltros();
              },
              rotulo: _rotuloNivelTensao,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChipInputField(
              key: const ValueKey('campo_conjunto'),
              label: 'Conjunto Elétrico',
              hint: 'ex: 17113',
              values: _conjCodes,
              onChanged: (v) {
                setState(() { _conjCodes..clear()..addAll(v); });
                _agendarAtualizacaoFiltros();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ChipInputField(
              key: const ValueKey('campo_subestacao'),
              label: 'Subestação',
              hint: 'ex: SJC',
              values: _subCodes,
              onChanged: (v) {
                setState(() { _subCodes..clear()..addAll(v); });
                _agendarAtualizacaoFiltros();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _OptionalFiltersCard(
              clasSubOptions: _clasSubOptions,
              clasSub: _clasSub,
              onClasSubChanged: (v) {
                setState(() { _clasSub..clear()..addAll(v); });
                _agendarAtualizacaoFiltros();
              },
              cnaeCodes: _cnaeCodes,
              onCnaeChanged: (v) {
                setState(() { _cnaeCodes..clear()..addAll(v); });
                _agendarAtualizacaoFiltros();
              },
              bairroNames: _bairroNames,
              onBairroChanged: (v) {
                setState(() { _bairroNames..clear()..addAll(v); });
                _agendarAtualizacaoFiltros();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildIndicadorDelimitacao(),
            const SizedBox(height: AppSpacing.sm),
            if (_totalFinal != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('$_totalFinal ponto(s) no resultado final.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarProjeto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _projetoSalvo ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _salvando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : _projetoSalvo
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Salvo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.check_circle_outline, size: 20),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Salvar Projeto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.save_outlined, size: 20),
                            ],
                          ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Text('Novo Projeto', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(width: 12),
            const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Busque a área de estudo, depois refine e salve o projeto.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        _fieldLabel('Nome do Projeto *'),
        TextField(
          controller: _nomeProjetoController,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'ex: Cobertura RF - Zona Leste SJC',
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  /// Mostra, de forma clara, qual delimitador vai ser usado no envio
  /// final — como os dois nunca se combinam (ou área desenhada, ou
  /// cidade inteira), isso deixa explícito qual dos dois está valendo
  /// no momento, sem precisar adivinhar.
  Widget _buildIndicadorDelimitacao() {
    final temArea = _areasMonitoramento.isNotEmpty;
    final texto = temArea
        ? 'Vai buscar só dentro da(s) ${_areasMonitoramento.length} área(s) desenhada(s) — as cidades inteiras não entram no envio.'
        : 'Vai buscar em toda(s) a(s) cidade(s) selecionada(s) — nenhuma área foi desenhada ainda.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: temArea ? Colors.deepOrange.withOpacity(0.08) : AppColors.infoBlueBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: temArea ? Colors.deepOrange.withOpacity(0.3) : AppColors.infoBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(temArea ? Icons.crop_square : Icons.location_city, size: 16, color: temArea ? Colors.deepOrange : AppColors.infoBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );
}

// ===========================================================================
// Multi-select de município — busca na API do IBGE, permite escolher
// 1 ou mais cidades. Campo simples (sem mapa/geocoding embutido — a
// Etapa 1 só usa o código, o mapa só aparece depois da busca real).
// ===========================================================================

class _MunicipioMultiSelectField extends StatefulWidget {
  final List<Municipio> selecionados;
  final String distCode;
  final ValueChanged<List<Municipio>> onChanged;

  const _MunicipioMultiSelectField({required this.selecionados, required this.distCode, required this.onChanged});

  @override
  State<_MunicipioMultiSelectField> createState() => _MunicipioMultiSelectFieldState();
}

class _MunicipioMultiSelectFieldState extends State<_MunicipioMultiSelectField> {
  final _ibge = IbgeService();
  final _pointsService = PointsFilterService();

  // Cache simples: já sabemos que essa cidade tem (true) ou não tem
  // (false) dado no banco — evita checar de novo a cada reabertura.
  final Map<int, bool> _validadas = {};

  Future<void> _abrirSeletor() async {
    final selecaoTemp = List<Municipio>.from(widget.selecionados);
    final resultado = await showDialog<List<Municipio>>(
      context: context,
      builder: (context) {
        final buscaController = TextEditingController();
        List<Municipio> resultados = [];
        bool buscando = false;
        int? validandoCodigo; // código IBGE em checagem no momento, pra mostrar o spinner na linha certa

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> buscar(String texto) async {
              if (texto.trim().length < 2) {
                setModalState(() => resultados = []);
                return;
              }
              setModalState(() => buscando = true);
              final r = await _ibge.buscarPorNome(texto);
              setModalState(() {
                resultados = r;
                buscando = false;
              });
            }

            Future<void> alternar(Municipio m, bool marcar) async {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();

              if (!marcar) {
                setModalState(() => selecaoTemp.remove(m));
                return;
              }

              // Já validamos essa cidade antes (nessa sessão do seletor)?
              final jaSabido = _validadas[m.codigoIbge];
              if (jaSabido == false) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.nome} não tem dados carregados no banco ainda.')));
                return;
              }
              if (jaSabido == true) {
                setModalState(() => selecaoTemp.add(m));
                return;
              }

              // Ainda não sabemos — pergunta pro backend (reaproveita o
              // POST /api/v1/points/filter que já existe, só com essa
              // cidade, pra ver se ele tem algum ponto cadastrado).
              if (widget.distCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preenche a Empresa/Distribuidora antes de escolher a cidade.')));
                return;
              }

              setModalState(() => validandoCodigo = m.codigoIbge);
              bool? temDado;
              try {
                final resultadoBusca = await _pointsService.buscarPontos(
                  distCodes: [widget.distCode],
                  munCodes: [m.codigoIbge.toString()],
                  countOnly: true,
                );
                temDado = resultadoBusca.totalPoints > 0;
              } catch (_) {
                // Erro de verdade (500, sem conexão, etc) — NÃO deixa
                // passar. Fica sem marcar no cache (pra poder tentar
                // de novo depois), mostra o erro, e não adiciona.
                temDado = null;
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Não foi possível confirmar com o servidor agora. Tente de novo em instantes.')));
                }
              }

              setModalState(() => validandoCodigo = null);

              if (temDado == null) return; // erro — já avisou acima, não adiciona

              _validadas[m.codigoIbge] = temDado;

              if (temDado) {
                setModalState(() => selecaoTemp.add(m));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('${m.nome} não tem dados carregados no banco ainda.')));
              }
            }

            final tamanhoTela = MediaQuery.of(context).size;
            final larguraDialogo = tamanhoTela.width < 520 ? tamanhoTela.width * 0.92 : 480.0;
            final alturaDialogo = tamanhoTela.height * 0.8;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: larguraDialogo,
                height: alturaDialogo,
                child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Município(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 20, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 4),
                      child: Text('Aparece o Brasil inteiro, mas só deixa marcar cidade com dado carregado no banco.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    TextField(
                      controller: buscaController,
                      onChanged: buscar,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Digite o nome da cidade (ex: São José)',
                        prefixIcon: buscando
                            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                            : const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (selecaoTemp.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selecaoTemp
                            .map((m) => Chip(
                                  label: Text(m.rotulo, style: const TextStyle(fontSize: 12)),
                                  onDeleted: () => setModalState(() => selecaoTemp.remove(m)),
                                  backgroundColor: AppColors.chipBg,
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: resultados.length,
                        itemBuilder: (context, i) {
                          final m = resultados[i];
                          final jaSelecionado = selecaoTemp.contains(m);
                          final validandoEssa = validandoCodigo == m.codigoIbge;
                          return CheckboxListTile(
                            value: jaSelecionado,
                            enabled: !validandoEssa,
                            title: Text(m.rotulo),
                            secondary: validandoEssa ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                            activeColor: AppColors.primary,
                            onChanged: validandoEssa ? null : (v) => alternar(m, v ?? false),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: validandoCodigo != null ? null : () => Navigator.pop(context, selecaoTemp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.inputFill,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
    if (resultado != null) widget.onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _abrirSeletor,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.location_city, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.selecionados.isEmpty ? 'Buscar município(s)...' : widget.selecionados.map((m) => m.nome).join(', '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: widget.selecionados.isEmpty ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Campo de "chips" — digita um código/nome, vira chip removível.
// ===========================================================================

class _ChipInputField extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const _ChipInputField({super.key, required this.label, required this.hint, required this.values, required this.onChanged});

  @override
  State<_ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<_ChipInputField> {
  final _controller = TextEditingController();

  void _adicionar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty || widget.values.contains(texto)) return;
    widget.onChanged([...widget.values, texto]);
    _controller.clear();
  }

  void _remover(String v) => widget.onChanged(widget.values.where((e) => e != v).toList());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _adicionar(),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _adicionar,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: AppColors.infoBlue),
              ),
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.values
                .map((v) => Chip(
                      label: Text(v, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _remover(v),
                      backgroundColor: AppColors.chipBg,
                      deleteIconColor: AppColors.textSecondary,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Multi-select com lista fixa (bottom sheet com checkboxes).
// ===========================================================================

class _MultiSelectSheetField extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Opcional — traduz o valor real (o que é salvo/enviado, ex:
  /// "medio") pra um rótulo bonito só pra mostrar na tela (ex:
  /// "Médio"). Sem isso, mostra o valor cru mesmo.
  final String Function(String valor)? rotulo;

  const _MultiSelectSheetField({required this.label, required this.options, required this.selected, required this.onChanged, this.rotulo});

  Future<void> _abrirSeletor(BuildContext context) async {
    final selecaoTemp = List<String>.from(selected);
    final resultado = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: options
                              .map((opt) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: selecaoTemp.contains(opt),
                                    title: Text(rotulo?.call(opt) ?? opt),
                                    activeColor: AppColors.primary,
                                    onChanged: (v) {
                                      setModalState(() {
                                        if (v == true) {
                                          selecaoTemp.add(opt);
                                        } else {
                                          selecaoTemp.remove(opt);
                                        }
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, selecaoTemp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (resultado != null) onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _abrirSeletor(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected.isEmpty ? label : selected.map((v) => rotulo?.call(v) ?? v).join(', '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: selected.isEmpty ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Card "Filtros Adicionais" — Classe/Subclasse, CNAE, Bairro.
// ===========================================================================

class _OptionalFiltersCard extends StatefulWidget {
  final List<String> clasSubOptions;
  final List<String> clasSub;
  final ValueChanged<List<String>> onClasSubChanged;
  final List<String> cnaeCodes;
  final ValueChanged<List<String>> onCnaeChanged;
  final List<String> bairroNames;
  final ValueChanged<List<String>> onBairroChanged;

  const _OptionalFiltersCard({
    required this.clasSubOptions,
    required this.clasSub,
    required this.onClasSubChanged,
    required this.cnaeCodes,
    required this.onCnaeChanged,
    required this.bairroNames,
    required this.onBairroChanged,
  });

  @override
  State<_OptionalFiltersCard> createState() => _OptionalFiltersCardState();
}

class _OptionalFiltersCardState extends State<_OptionalFiltersCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E8EF)), borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          trailing: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22, color: AppColors.textSecondary),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune, size: 18, color: AppColors.primary),
          ),
          title: const Text('Filtros Adicionais', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          subtitle: const Text('Classe, CNAE e bairro', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          children: [
            _MultiSelectSheetField(label: 'Classe / Subclasse', options: widget.clasSubOptions, selected: widget.clasSub, onChanged: widget.onClasSubChanged),
            const SizedBox(height: AppSpacing.md),
            _ChipInputField(key: const ValueKey('campo_cnae'), label: 'Código CNAE', hint: 'ex: 3511-5/01', values: widget.cnaeCodes, onChanged: widget.onCnaeChanged),
            const SizedBox(height: AppSpacing.md),
            _ChipInputField(key: const ValueKey('campo_bairro'), label: 'Nome do Bairro', hint: 'ex: Jardim Aquarius', values: widget.bairroNames, onChanged: widget.onBairroChanged),
          ],
        ),
      ),
    );
  }
}