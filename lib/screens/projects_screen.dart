import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_footer.dart';
import '../widgets/common/page_body.dart';
import 'new_project_screen.dart';

/// "My Projects" screen. Mesmo padrão da MapScreen: [PageBody] garante
/// Material ancestral em qualquer contexto, [LayoutBuilder] escolhe
/// entre o layout mobile (lista) e o layout web (dashboard — header +
/// botão no topo, cards de métrica em linha, grade de projetos,
/// rodapé). O conteúdo (3 projetos, 2 métricas) é o mesmo nas duas —
/// só o arranjo muda.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  static const _webBreakpoint = 900.0;

  // Índice da aba "New Project" no AppShell (Projects=0, New Project=1, Map=2).
  static const _newProjectTabIndex = 1;

  void _goToNewProject(BuildContext context) {
    final shell = AppShell.of(context);
    if (shell != null) {
      shell.goToTab(_newProjectTabIndex);
    } else {
      // Fallback defensivo, só usado se esta tela for aberta fora do
      // AppShell (ex: em testes) — NewProjectScreen tem seu próprio
      // PageBody, então continua funcionando mesmo empilhada assim.
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
                    Row(
                      children: [
                        const Text(
                          'My Projects',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(100)),
                          child: const Text(
                            '3 active',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Supply chain deployments',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _goToNewProject(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 6),
                    Text('New Project', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'SYNC STATUS',
                  icon: Icons.cloud_done_outlined,
                  value: '100%',
                  caption: 'Up to date',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: 'REPORTS READY',
                  icon: Icons.picture_as_pdf_outlined,
                  value: '3 Files',
                  caption: 'Ready',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: const [
                Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Search projects or city...', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                ),
                Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Grade de cards — responsiva: 3 colunas em telas bem largas, 2 em telas médias.
          LayoutBuilder(
            builder: (context, gridConstraints) {
              final columns = gridConstraints.maxWidth >= 1100 ? 3 : 2;
              const spacing = AppSpacing.md;
              final cardWidth = (gridConstraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _projects
                    .map((p) => SizedBox(width: cardWidth, child: _ProjectCard(data: p)))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT (inalterado)
  // ---------------------------------------------------------------------

  Widget _buildMobileBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
        // Top bar
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
                Text(
                  'Projects',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'My Projects',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(100)),
                        child: const Text(
                          '3 active',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('Supply chain deployments', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _goToNewProject(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 6),
                Text('New Project', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _MetricCard(label: 'SYNC STATUS', icon: Icons.cloud_done_outlined, value: '100%', caption: 'Up to date'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(label: 'REPORTS READY', icon: Icons.picture_as_pdf_outlined, value: '3 Files', caption: 'Ready'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: const [
              Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Search projects or city...', style: TextStyle(fontSize: 15, color: AppColors.textSecondary))),
              Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final p in _projects) ...[
          _ProjectCard(data: p),
          const SizedBox(height: AppSpacing.md),
        ],
            ]),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
          ),
        ),
      ],
    );
  }
}

// Dado único compartilhado pelos dois layouts — muda aqui, muda nos dois.
const _projects = [
  _ProjectData(
    category: 'ACTIVE HUB',
    name: 'Project Alpha',
    location: 'São Paulo',
    date: 'Oct 14, 2024',
    subtype: 'Distribution Center 01',
    subtypeIcon: Icons.home_work_outlined,
    status: 'Operational',
  ),
  _ProjectData(
    category: 'FULFILLMENT CENTER',
    name: 'Project Beta',
    location: 'Rio de Janeiro',
    date: 'Oct 22, 2024',
    subtype: 'Cross-Dock Facility B',
    subtypeIcon: Icons.local_shipping_outlined,
    status: 'Transit Inbound',
  ),
  _ProjectData(
    category: 'COLD STORAGE DEPOT',
    name: 'Project Gamma',
    location: 'Curitiba',
    date: 'Nov 02, 2024',
    subtype: 'Automated Storage System',
    subtypeIcon: Icons.inventory_2_outlined,
    status: 'Verified',
  ),
];

class _ProjectData {
  final String category, name, location, date, subtype, status;
  final IconData subtypeIcon;
  const _ProjectData({
    required this.category,
    required this.name,
    required this.location,
    required this.date,
    required this.subtype,
    required this.subtypeIcon,
    required this.status,
  });
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
  final _ProjectData data;
  const _ProjectCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(data.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3)),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_downward, size: 16, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(data.location, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(data.date, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDEFF3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(data.subtypeIcon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(data.subtype, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              Text(data.status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}