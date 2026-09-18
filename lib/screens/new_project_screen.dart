import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/bottom_nav_bar.dart';
import 'map_screen.dart';
import 'projects_screen.dart';

/// "New Project" screen — built strictly to spec: top bar with logo +
/// "TECSYS B2B" / "New Project" + profile avatar, "Deployment 01 •
/// Draft Mode" badge row, page header, three labeled fields with
/// prefix icons, the "Advanced Settings" expandable card, the "Save
/// and Continue" button, footer note, and the bottom nav bar.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _regionController = TextEditingController();
  final _providerController = TextEditingController();
  final _equipmentController = TextEditingController();

  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  String _protocol = 'HTTPS';
  String _syncInterval = 'Real-time';
  bool _offlineBuffer = false;
  String _teamAccess = 'Distribution Center Staff';

  @override
  void dispose() {
    _regionController.dispose();
    _providerController.dispose();
    _equipmentController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _handleTabTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProjectsScreen()),
        );
        break;
      case 1:
        break; // already here
      case 2:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        break;
      default:
        showAccountMenu(context);
    }
  }

  Widget _subLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(currentIndex: 1, onTap: _handleTabTap),
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
                      'New Project',
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
            // Deployment 01 • Draft Mode
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Deployment 01',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Draft Mode', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'New Project',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Configure basic deployment parameters.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthTextField(
              label: 'Region *',
              hint: 'e.g., Southeast / SP',
              controller: _regionController,
              prefixIcon: Icons.public,
              trailing: _subLabel('Geographic Zone'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthTextField(
              label: 'Energy Provider *',
              hint: 'e.g., Enel Distribuição',
              controller: _providerController,
              prefixIcon: Icons.bolt,
              trailing: _subLabel('Local Grid'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthTextField(
              label: 'Equipment Type *',
              hint: 'e.g., Solar Inverter B2',
              controller: _equipmentController,
              prefixIcon: Icons.settings_input_antenna,
              trailing: _subLabel('Hardware profile'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AdvancedSettingsCard(
              hostController: _hostController,
              portController: _portController,
              protocol: _protocol,
              onProtocolChanged: (v) => setState(() => _protocol = v ?? _protocol),
              syncInterval: _syncInterval,
              onSyncIntervalChanged: (v) => setState(() => _syncInterval = v ?? _syncInterval),
              offlineBuffer: _offlineBuffer,
              onOfflineBufferChanged: (v) => setState(() => _offlineBuffer = v),
              teamAccess: _teamAccess,
              onTeamAccessChanged: (v) => setState(() => _teamAccess = v ?? _teamAccess),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project created with advanced configuration!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Save and Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Parameters saved automatically to cloud inventory',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedSettingsCard extends StatefulWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final String protocol;
  final ValueChanged<String?> onProtocolChanged;
  final String syncInterval;
  final ValueChanged<String?> onSyncIntervalChanged;
  final bool offlineBuffer;
  final ValueChanged<bool> onOfflineBufferChanged;
  final String teamAccess;
  final ValueChanged<String?> onTeamAccessChanged;

  const _AdvancedSettingsCard({
    required this.hostController,
    required this.portController,
    required this.protocol,
    required this.onProtocolChanged,
    required this.syncInterval,
    required this.onSyncIntervalChanged,
    required this.offlineBuffer,
    required this.onOfflineBufferChanged,
    required this.teamAccess,
    required this.onTeamAccessChanged,
  });

  @override
  State<_AdvancedSettingsCard> createState() => _AdvancedSettingsCardState();
}

class _AdvancedSettingsCardState extends State<_AdvancedSettingsCard> {
  bool _expanded = false;

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  Widget _dropdown<T extends String>(List<String> options, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E8EF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          trailing: Icon(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 22,
            color: AppColors.textSecondary,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune, size: 18, color: AppColors.primary),
          ),
          title: const Text(
            'Advanced Settings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          subtitle: const Text(
            'Voltage & transmission scope',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          children: [
            _fieldLabel('IP / Server Host'),
            TextField(
              controller: widget.hostController,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _fieldDecoration('192.168.1.100 or server.domain.com'),
            ),
            const SizedBox(height: AppSpacing.md),
            _fieldLabel('Port & Protocol'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: widget.portController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: _fieldDecoration('8080'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _dropdown(
                    const ['HTTPS', 'MQTT', 'WebSocket'],
                    widget.protocol,
                    widget.onProtocolChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _fieldLabel('Sync Interval'),
            _dropdown(
              const ['Real-time', 'Every 15 minutes', 'Hourly', 'Daily'],
              widget.syncInterval,
              widget.onSyncIntervalChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widget.offlineBuffer,
              onChanged: widget.onOfflineBufferChanged,
              activeColor: AppColors.primary,
              title: const Text(
                'Offline Buffer Mode',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              subtitle: const Text(
                'Enable offline data buffering',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _fieldLabel('Team Access / Role'),
            _dropdown(
              const ['Distribution Center Staff', 'Regional Managers', 'Full Admin'],
              widget.teamAccess,
              widget.onTeamAccessChanged,
            ),
          ],
        ),
      ),
    );
  }
}
