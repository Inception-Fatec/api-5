import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/bottom_nav_bar.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'new_project_screen.dart';
import 'projects_screen.dart';

/// Reset Password screen, mobile layout.
///
/// The reference image was a desktop page (horizontal top bar + wide
/// footer), but the app is mobile-only, so the card content is kept
/// exactly as specified while the desktop-only chrome is replaced by
/// the same mobile top row + bottom nav used on the other screens.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
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
        break; // already in the account flow
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(currentIndex: 3, onTap: _handleTabTap),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Mobile top row: logo + TECSYS B2B / screen name + avatar,
            // same pattern as the New Project screen.
            Row(
              children: [
                Image.asset('assets/images/logo.png', height: 26),
                const Spacer(),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TECSYS B2B',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Reset Password',
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
            const SizedBox(height: AppSpacing.xl),
            // Lock-with-reset-arrow icon in a soft rounded container.
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_reset, size: 28, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // "Tecsys" + "ID" badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tecsys',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ID',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Reset Password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Enter your corporate email to receive password reset instructions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthTextField(
              label: 'Corporate Email',
              hint: 'name@company.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              trailing: const Text(
                'SSO Enabled',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Back to Login', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Tecsys Identity & Access Management v4.2',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
