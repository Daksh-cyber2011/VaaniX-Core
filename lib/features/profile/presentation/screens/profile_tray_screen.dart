/// VaaniX V1 Design System — Profile & Preferences Tray
///
/// Stitch Design Canvas: Screen 4
/// Hybrid Neutral (#F8FAFC)
///
/// Features:
/// - User Identity: Daksh Sharma (ID: VX-9832) with Exam Mode Active badge & switch
/// - Metric Trio: 18 Day Streak, 4.2k XP, 88% Accuracy
/// - Mascot Config: VAN (Duck) • MENTOR (Mood: Focused & Ready, Rename action)
/// - Multi-profile Management: Active Learn languages + Add New Language
/// - Active Exam Slot: CBSE Class 10 Hindi Course A
/// - High Visual Gravity Zone: Isolated Exam reset without wiping Learn records
/// - Preferences: Daily study reminders, board urgency alerts, flash drills
/// - Offline Content Manager: 552 MB cached with Clear Cache CTA
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/providers/app_mode_provider.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/van/domain/van_state.dart';
import 'package:vaanix_app/shared/widgets/vaanix_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_card.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ProfileTrayScreen extends ConsumerStatefulWidget {
  const ProfileTrayScreen({super.key});

  @override
  ConsumerState<ProfileTrayScreen> createState() => _ProfileTrayScreenState();
}

class _ProfileTrayScreenState extends ConsumerState<ProfileTrayScreen> {
  bool _dailyReminders = true;
  bool _boardUrgencyAlerts = true;
  bool _flashDrills = true;
  int _cachedMegabytes = 552;

  void _showRenameVanDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderLg),
        title: const Text('Rename VAN', style: TextStyle(fontFamily: 'Poppins')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter companion name',
            border: OutlineInputBorder(borderRadius: VaaniXRadius.borderMd),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProfileProvider.notifier).updateCompanionName(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetExamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderLg),
        title: const Text(
          'Reset Exam Profile?',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: VaaniXColors.telemetryRose,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will reset your CBSE Class 10 syllabus diagnostic and mock records. '
          'Your Learn Mode languages (Hindi, Tamil), streaks, and total XP remain completely safe.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VaaniXColors.telemetryRose,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exam track reset successfully. Learn progress preserved.'),
                ),
              );
            },
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final activeMode = ref.watch(appModeProvider);
    final companionName = profile.resolvedCompanionName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? VaaniXColors.bgDark : VaaniXColors.bgLight,
      appBar: AppBar(
        title: const Text('Profile & Preferences'),
        centerTitle: false,
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: VaaniXSpacing.screenMarginWide,
          vertical: VaaniXSpacing.md,
        ),
        children: [
          // 1. User Identity Card
          _buildIdentityCard(context, activeMode),
          const SizedBox(height: VaaniXSpacing.md),

          // 2. Metric Trio (Streak, XP, Accuracy)
          _buildMetricTrio(profile.currentStreak, profile.xpTotal),
          const SizedBox(height: VaaniXSpacing.lg),

          // 3. Mascot Config Card
          _buildMascotConfigCard(context, companionName),
          const SizedBox(height: VaaniXSpacing.lg),

          // 4. Multi-Profile Management (Learn Languages)
          _buildLearnProfilesSection(context),
          const SizedBox(height: VaaniXSpacing.lg),

          // 5. Active Exam Slot with High Visual Gravity Zone
          _buildExamProfileSection(context),
          const SizedBox(height: VaaniXSpacing.lg),

          // 6. Preferences & System Toggles
          _buildPreferencesSection(context),
          const SizedBox(height: VaaniXSpacing.lg),

          // 7. Offline Content Manager
          _buildOfflineManagerCard(context),
          const SizedBox(height: VaaniXSpacing.xl),

          // 8. Sign Out
          VaaniXButton.outline(
            label: 'Sign Out (VX-9832)',
            icon: const Icon(Icons.logout_rounded, size: 18),
            onPressed: () {
              context.go(RouteNames.auth);
            },
          ),
          const SizedBox(height: VaaniXSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, AppMode activeMode) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person_outline_rounded,
              color: VaaniXColors.learnPrimaryViolet,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daksh Sharma',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: VX-9832 · ${activeMode == AppMode.exam ? 'Exam Mode Active' : 'Learn Mode Active'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: VaaniXColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(appModeProvider.notifier).toggleMode();
            },
            child: const Text(
              'Switch',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: VaaniXColors.learnPrimaryViolet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTrio(int streak, int xp) {
    final displayStreak = streak > 0 ? streak : 18;
    final displayXp = xp > 0 ? '${(xp / 1000).toStringAsFixed(1)}k' : '4.2k';

    return Row(
      children: [
        Expanded(child: _MetricTile(emoji: '🔥', value: '$displayStreak Days', label: 'Streak')),
        const SizedBox(width: 10),
        Expanded(child: _MetricTile(emoji: '⚡', value: displayXp, label: 'XP Earned')),
        const SizedBox(width: 10),
        Expanded(child: _MetricTile(emoji: '🎯', value: '88%', label: 'Accuracy')),
      ],
    );
  }

  Widget _buildMascotConfigCard(BuildContext context, String companionName) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VaaniXColors.learnSoftPurple,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: ClipOval(
                child: VanWidget(
                  size: 44,
                  state: VanState.happy,
                  showSpeechBubble: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$companionName (Duck) • MENTOR',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Mood: Focused & Ready',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: VaaniXColors.telemetryEmerald,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rename Companion',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showRenameVanDialog(context, companionName),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnProfilesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learn Mode Profiles',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        // Hindi Profile
        VaaniXCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Text('🇮🇳', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hindi • Level 2',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '65% Unit 4 Completed',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: VaaniXColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VaaniXColors.telemetryEmeraldBg,
                  borderRadius: VaaniXRadius.borderPill,
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: VaaniXColors.telemetryEmerald,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Tamil Profile
        VaaniXCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Text('🔤', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tamil • Foundation',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '30% Unit 1 Completed',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: VaaniXColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: VaaniXColors.textTertiaryLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Add Language
        OutlinedButton.icon(
          onPressed: () => context.push(RouteNames.learnLanguageSelection),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('+ Add New Language (8 Available)'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderMd),
            minimumSize: const Size(double.infinity, 42),
          ),
        ),
      ],
    );
  }

  Widget _buildExamProfileSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Exam Track',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        VaaniXCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded,
                      color: VaaniXColors.examIndigoAccent, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'CBSE Class 10 Hindi Course A',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VaaniXColors.examSurface,
                      borderRadius: VaaniXRadius.borderPill,
                    ),
                    child: const Text(
                      'Board 2026',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: VaaniXColors.examPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // High Visual Gravity Zone
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VaaniXColors.telemetryRoseBg,
                  borderRadius: VaaniXRadius.borderMd,
                  border: Border.all(
                    color: VaaniXColors.telemetryRose.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: VaaniXColors.telemetryRose),
                        SizedBox(width: 8),
                        Text(
                          'High Visual Gravity Zone',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: VaaniXColors.telemetryRose,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Resetting your exam profile resets mock test scores and chapter diagnostics. Learn Mode languages remain completely intact.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: VaaniXColors.textSecondaryLight,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    VaaniXButton.danger(
                      label: 'Reset Exam Track',
                      height: 38,
                      onPressed: () => _showResetExamDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences & System',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily Study Reminders (7:30 PM)'),
            value: _dailyReminders,
            onChanged: (v) => setState(() => _dailyReminders = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Board Urgency Alerts (30 Days Prior)'),
            value: _boardUrgencyAlerts,
            onChanged: (v) => setState(() => _boardUrgencyAlerts = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Weak Area Flash Drills'),
            value: _flashDrills,
            onChanged: (v) => setState(() => _flashDrills = v),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineManagerCard(BuildContext context) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined,
                  size: 20, color: VaaniXColors.telemetryEmerald),
              const SizedBox(width: 8),
              const Text(
                'Offline Content Manager',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$_cachedMegabytes MB cached',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VaaniXColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'All syllabi, questions (2018-2024), and audio cadence models are available offline.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: VaaniXColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() => _cachedMegabytes = 120);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleaned. 120 MB essential data kept.')),
              );
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderMd),
            ),
            child: const Text('Clear Audio Waveform Cache'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: VaaniXColors.learnSurfaceCard,
        borderRadius: VaaniXRadius.borderMd,
        border: Border.all(color: VaaniXColors.learnBorder),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10.5,
              color: VaaniXColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
