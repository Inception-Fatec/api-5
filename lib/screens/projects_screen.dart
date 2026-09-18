import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'new_project_screen.dart';
import 'reset_password_screen.dart';
import 'map_screen.dart';

/// "My Projects" screen — built strictly to spec: top bar, header
/// with active-project count and "+ New Project", the two metric
/// cards, the search bar, and the project list.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  void _handleTabTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        break; // already here
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewProjectScreen()),
        );
        break;
      case 2:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        break;
      default:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (i) => _handleTabTap(context, i),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
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
            // My Projects header + New Project button
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
                            decoration: BoxDecoration(
                              color: AppColors.chipBg,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              '3 active',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Supply chain deployments',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
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
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NewProjectScreen()),
                  );
                },
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
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Search projects or city...',
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ),
                  const Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ProjectCard(
              category: 'ACTIVE HUB',
              name: 'Project Alpha',
              location: 'São Paulo',
              date: 'Oct 14, 2024',
              subtype: 'Distribution Center 01',
              subtypeIcon: Icons.home_work_outlined,
              status: 'Operational',
            ),
            const SizedBox(height: AppSpacing.md),
            const _ProjectCard(
              category: 'FULFILLMENT CENTER',
              name: 'Project Beta',
              location: 'Rio de Janeiro',
              date: 'Oct 22, 2024',
              subtype: 'Cross-Dock Facility B',
              subtypeIcon: Icons.local_shipping_outlined,
              status: 'Transit Inbound',
            ),
            const SizedBox(height: AppSpacing.md),
            const _ProjectCard(
              category: 'COLD STORAGE DEPOT',
              name: 'Project Gamma',
              location: 'Curitiba',
              date: 'Nov 02, 2024',
              subtype: 'Automated Storage System',
              subtypeIcon: Icons.inventory_2_outlined,
              status: 'Verified',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String caption;

  const _MetricCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3),
              ),
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
  final String category;
  final String name;
  final String location;
  final String date;
  final String subtype;
  final IconData subtypeIcon;
  final String status;

  const _ProjectCard({
    required this.category,
    required this.name,
    required this.location,
    required this.date,
    required this.subtype,
    required this.subtypeIcon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E8EF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_downward, size: 16, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(location, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(date, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                  Icon(subtypeIcon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(subtype, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
