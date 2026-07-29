import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/features/settings/controllers/settings_controller.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<SettingsController>()) {
      Get.put(SettingsController());
    }
    _settingsController = Get.find<SettingsController>();
    Future.microtask(() => _settingsController.loadSettings());
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out of Poker Night?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          PNButton(
            destructive: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              Get.find<AuthController>().logout();
            },
            label: 'Sign Out',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.darkSurface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Obx(() {
            final settings = _settingsController.state.value;
            final user = Get.find<AuthController>().currentUser.value;
            final isDarkMode = settings.themeMode == ThemeMode.dark ||
                (settings.themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SectionHeader(label: 'Account'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: PNCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                          child: Center(
                            child: Text(
                              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.name ?? 'Player', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionHeader(label: 'Appearance'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: PNCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          subtitle: const Text('Premium dark interface', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                            child: Icon(isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: isDarkMode ? AppColors.gold : Colors.orange, size: 20),
                          ),
                          value: isDarkMode,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) => _settingsController.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionHeader(label: 'Notifications & Audio'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: PNCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          subtitle: const Text('Game reminders & updates', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.notifications_outlined, color: AppColors.accent, size: 20),
                          ),
                          value: settings.notificationsEnabled,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) => _settingsController.setNotificationsEnabled(v),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          title: const Text('Voice Announcements', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          subtitle: const Text('Blinds & alerts spoken aloud', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.record_voice_over_rounded, color: AppColors.green, size: 20),
                          ),
                          value: settings.voiceEnabled,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) => _settingsController.setVoiceEnabled(v),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          title: const Text('Sound Effects', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          subtitle: const Text('UI sounds and chip sounds', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.music_note_rounded, color: AppColors.gold, size: 20),
                          ),
                          value: settings.soundEnabled,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) => _settingsController.setSoundEnabled(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionHeader(label: 'Legal & Support'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: PNCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsNavItem(icon: Icons.privacy_tip_outlined, iconColor: AppColors.purple, label: 'Privacy Policy', onTap: () => _launchURL('https://example.com/privacy')),
                        const Divider(height: 1, color: Colors.white12),
                        _SettingsNavItem(icon: Icons.article_outlined, iconColor: AppColors.blue, label: 'Terms of Service', onTap: () => _launchURL('https://example.com/terms')),
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                          ),
                          title: const Text('Version', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('v1.0.0', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PNButton(
                    destructive: true,
                    outlined: true,
                    onPressed: _confirmLogout,
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SettingsNavItem({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
      onTap: onTap,
    );
  }
}
