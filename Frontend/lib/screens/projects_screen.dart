import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../services/project_model.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../utils/distribuidoras.dart';
import '../widgets/common/app_footer.dart';
import '../widgets/common/page_body.dart';
import 'new_project_screen.dart';
import 'reports_screen.dart';

/// "My Projects" screen. Mesmo padrão da MapScreen/NewProjectScreen:
/// [PageBody] garante Material ancestral em qualquer contexto,
/// [LayoutBuilder] escolhe entre o layout mobile (lista) e o layout
/// web (dashboard). Web e mobile compartilham exatamente os mesmos
/// dados e a mesma lógica (busca, métricas, cards) — só o ARRANJO
/// muda entre os dois builds lá embaixo, nunca o conteúdo.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static const _webBreakpoint = 900.0;

  // Índice da aba "New Project" no AppShell (Projects=0, New Project=1, Map=2).
  static const _newProjectTabIndex = 1;

  final _service = ProjectsService();
  final _buscaController = TextEditingController();

  List<Project> _projects = [];
  bool _carregando = true;
  String? _erro;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultado = await _service.listar();
      if (!mounted) return;
      setState(() {
        _projects = resultado;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar os projetos agora.';
      });
    }
  }

  // Busca simples: nome do projeto ou nome/código da empresa,
  // ignorando maiúscula/minúscula.
  List<Project> get _projetosFiltrados {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return _projects;
    return _projects.where((p) {
      final nomeEmpresa = nomeDistribuidora(p.distCode).toLowerCase();
      return p.name.toLowerCase().contains(termo) ||
          nomeEmpresa.contains(termo) ||
          p.distCode.toLowerCase().contains(termo);
    }).toList();
  }

  int get _totalProjetos => _projects.length;
  int get _totalCalculados => _projects.where((p) => p.status == 'SUCESSO').length;

  void _goToNewProject(BuildContext context) {
    final shell = AppShell.of(context);
    if (shell != null) {
      shell.goToTab(_newProjectTabIndex);
    } else {
      // Fallback defensivo, só usado se esta tela for aberta fora do
      // AppShell (ex: em testes).
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewProjectScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= _webBreakpoint;
          return isWeb ? _buildWebBody(context) : _buildMobileBody(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Blocos compartilhados — web e mobile chamam os mesmos métodos, só
  // arrumados de jeitos diferentes nos builds abaixo.
  // ---------------------------------------------------------------------

  Widget _buildTitulo(double fontSize) {
    return Row(
      children: [
        Text('My Projects', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(100)),
          child: Text(
            '$_totalProjetos ${_totalProjetos == 1 ? "projeto" : "projetos"}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildNovoProjetoButton(BuildContext context, {required bool full}) {
    final botao = ElevatedButton(
      onPressed: () => _goToNewProject(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: full ? 0 : 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: full ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        children: const [
          Icon(Icons.add, size: 18),
          SizedBox(width: 6),
          Text('New Project', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return full ? SizedBox(width: double.infinity, height: 48, child: botao) : botao;
  }

  Widget _buildMetricas() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'TOTAL DE PROJETOS',
            icon: Icons.folder_copy_outlined,
            value: '$_totalProjetos',
            caption: _totalProjetos == 1 ? 'projeto' : 'projetos',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            label: 'PROJETOS CALCULADOS',
            icon: Icons.check_circle_outline,
            value: '$_totalCalculados',
            caption: 'concluídos',
          ),
        ),
      ],
    );
  }

  Widget _buildBusca() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _buscaController,
              onChanged: (v) => setState(() => _busca = v),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar por nome do projeto ou empresa...',
                hintStyle: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_busca.isNotEmpty)
            InkWell(
              onTap: () => setState(() {
                _busca = '';
                _buscaController.clear();
              }),
              child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildListaOuEstado({required bool grid}) {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_erro != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text(_erro!, style: const TextStyle(fontSize: 14, color: Colors.redAccent)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _carregar, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    final projetos = _projetosFiltrados;
    if (projetos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            _projects.isEmpty ? 'Nenhum projeto criado ainda.' : 'Nenhum projeto encontrado para essa busca.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (grid) {
      return LayoutBuilder(
        builder: (context, gridConstraints) {
          final columns = gridConstraints.maxWidth >= 1100 ? 3 : 2;
          const spacing = AppSpacing.md;
          final cardWidth = (gridConstraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: projetos.map((p) => SizedBox(width: cardWidth, child: _ProjectCard(data: p))).toList(),
          );
        },
      );
    }
    return Column(
      children: [
        for (final p in projetos) ...[
          _ProjectCard(data: p),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // WEB LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildWebBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitulo(26),
                          const SizedBox(height: 4),
                          const Text('Supply chain deployments', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    _buildNovoProjetoButton(context, full: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildMetricas(),
                const SizedBox(height: AppSpacing.lg),
                _buildBusca(),
                const SizedBox(height: AppSpacing.lg),
                _buildListaOuEstado(grid: true),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: const [AppFooter()]),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildMobileBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 26),
                  const Spacer(),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TECSYS B2B',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
                      ),
                      SizedBox(height: 2),
                      Text('Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 18, color: Colors.white)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildTitulo(24),
              const SizedBox(height: 2),
              const Text('Supply chain deployments', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              _buildNovoProjetoButton(context, full: true),
              const SizedBox(height: AppSpacing.lg),
              _buildMetricas(),
              const SizedBox(height: AppSpacing.lg),
              _buildBusca(),
              const SizedBox(height: AppSpacing.lg),
              _buildListaOuEstado(grid: false),
            ]),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: const [AppFooter()]),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String caption;

  const _MetricCard({required this.label, required this.icon, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3)),
              Icon(icon, size: 17, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              Text(caption, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project data;
  const _ProjectCard({required this.data});

  void _abrirDetalhe(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = ProjectStatusStyle.color(data.status);
    return InkWell(
      onTap: () => _abrirDetalhe(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E8EF)), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    nomeDistribuidora(data.distCode),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  ProjectStatusStyle.label(data.status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('ID #${data.id}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDEFF3)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(data.dataFormatada, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  data.criadoPorLabel,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}