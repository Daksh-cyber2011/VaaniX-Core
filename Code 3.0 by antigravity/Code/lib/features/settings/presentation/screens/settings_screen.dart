/// Settings Screen
///
/// Notifications, daily goal, language (EN/HI), account.
/// Full impl: Settings milestone.
///
/// PRD Section 7 — Settings

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.titleLarge()),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            subtitle: 'Reminders and updates',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.flag_outlined,
            label: 'Daily Goal',
            subtitle: '10 minutes per day',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            label: 'Language',
            subtitle: 'English',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Account',
            subtitle: 'Manage your account',
            onTap: () {},
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'VaaniX v1.0.0',
              style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, style: AppTextStyles.titleSmall()),
        subtitle: Text(subtitle,
            style: AppTextStyles.bodySmall(color: AppColors.subtextLight)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
