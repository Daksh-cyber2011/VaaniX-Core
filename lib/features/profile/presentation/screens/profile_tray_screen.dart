/// VaaniX V1 Design System — Profile & Preferences Tray
///
/// Stitch Design Canvas: Screen 4
/// Hybrid Neutral (#F8FAFC)
///
/// Data provenance (audited — the Stitch mock values this screen shipped
/// with were indistinguishable from real data, so each row is now either
/// live or an explicit unavailable state):
/// - User identity: `userProfileProvider.resolvedDisplayName`; neutral
///   label when unset. No user-facing account ID exists in the model.
/// - Streak / XP: live (`userProfileProvider`, `xpTotalProvider`), zeros
///   shown as zeros.
/// - Accuracy: NO source in the architecture — shown as unavailable.
/// - Mascot: companion name + `personalityMode` (both real); there is no
///   mood concept, so none is displayed.
/// - Learn profiles: `kLearnLanguageCatalogue` × `hasProfile`, selected
///   language marked active. No per-language percentage exists.
/// - Active exam track: `examActiveTrackIdProvider` + `courseSyllabusProvider`.
/// - Exam reset: clears the four §21 per-track stores, Learn untouched.
/// - Preferences toggles: local UI state only — see the note on
///   [_buildPreferencesSection].
/// - Offline Content Manager: states that curriculum content ships
///   bundled with the app (no separate downloadable cache exists yet)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaanix_app/core/navigation/push_unique.dart';
import 'package:vaanix_app/core/logging/logger.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_diagnostic_providers.dart'
    show examLearnerProfileProvider, examLearnerProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_loader.dart'
    show courseSyllabusProvider;
import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart'
    show CourseSyllabus;
import 'package:vaanix_app/features/exam/presentation/providers/exam_hub_providers.dart'
    show examActiveTrackIdProvider, examHubSnapshotProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_profile_providers.dart'
    show
        examProfileMapProvider,
        examProfileProvider,
        examProfileRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/exam_repository_providers.dart'
    show mockResultRepositoryProvider, pyqPerformanceRepositoryProvider;
import 'package:vaanix_app/features/exam/presentation/providers/pyq_mock_providers.dart'
    show examMockProvider, examPyqProvider;
import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/providers/app_mode_provider.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';
import 'package:vaanix_app/core/theme/vaanix_spacing.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart'
    show PersonalityMode;
import 'package:vaanix_app/features/learn/domain/learn_language.dart'
    show kLearnLanguageCatalogue;
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart'
    show selectedLearnLanguageProvider;
import 'package:vaanix_app/features/learn/presentation/providers/learn_profile_providers.dart'
    show learnProfileRepositoryProvider;
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
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

  void _showRenameVanDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderLg),
        title:
            const Text('Rename VAN', style: TextStyle(fontFamily: 'Poppins')),
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
                ref
                    .read(userProfileProvider.notifier)
                    .updateCompanionName(newName);
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
    showDialog<void>(
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
        // Copy describes exactly what the reset deletes — the four §21
        // per-track stores cleared in [_performExamTrackReset] — and
        // nothing more.
        content: const Text(
          "This clears the active exam track's study profile, diagnostic "
          'result, PYQ evidence and mock history. Learn Mode progress, '
          'streaks and XP are not touched.',
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
              _performExamTrackReset();
            },
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  /// Clears every §21 per-track store for the ACTIVE exam track.
  ///
  /// Contract (the original implementation violated all of it: it popped the
  /// dialog and announced success while touching nothing):
  ///   * the track id comes from the real scope store, not a constant;
  ///   * each removal is a production API — no `@visibleForTesting` call;
  ///   * success is reported only after every write has completed;
  ///   * a failure is logged and reported to the learner as a failure.
  ///
  /// Learn Mode stores are deliberately absent, and each repository's
  /// `remove` drops a single track from its document, so sibling exam
  /// tracks survive too.
  Future<void> _performExamTrackReset() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final trackId = await ref.read(examActiveTrackIdProvider.future);
      if (trackId == null || trackId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No exam track is active, so there is nothing '
                'to reset.'),
          ),
        );
        return;
      }

      await ref.read(examProfileRepositoryProvider).remove(trackId);
      await ref.read(examLearnerProfileRepositoryProvider).remove(trackId);
      await ref.read(pyqPerformanceRepositoryProvider).remove(trackId);
      await ref.read(mockResultRepositoryProvider).remove(trackId);

      // Derived state: the hub/pyq/mock providers read their repositories
      // with `ref.read`, so they do not rebuild on their own.
      ref.invalidate(examProfileMapProvider);
      ref.invalidate(examProfileProvider(trackId));
      ref.invalidate(examLearnerProfileProvider(trackId));
      ref.invalidate(examHubSnapshotProvider(trackId));
      ref.invalidate(examPyqProvider(trackId));
      ref.invalidate(examMockProvider(trackId));

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Exam track reset. Learn Mode progress preserved.'),
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Exam track reset failed',
        tag: 'ProfileTrayScreen',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Exam track reset failed. Your data has not been '
              'changed. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final xpTotal = ref.watch(xpTotalProvider);
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
          _buildIdentityCard(context, activeMode, profile.resolvedDisplayName),
          const SizedBox(height: VaaniXSpacing.md),

          // 2. Metric Trio (Streak, XP, Accuracy)
          _buildMetricTrio(profile.currentStreak, xpTotal),
          const SizedBox(height: VaaniXSpacing.lg),

          // 3. Mascot Config Card
          _buildMascotConfigCard(
              context, companionName, profile.personalityMode),
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
            label: 'Sign Out',
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

  Widget _buildIdentityCard(
      BuildContext context, AppMode activeMode, String displayName) {
    return VaaniXCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor:
                VaaniXColors.learnPrimaryViolet.withValues(alpha: 0.12),
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
                Text(
                  // Real profile name. `resolvedDisplayName` is empty until
                  // the learner sets one (the model treats empty as
                  // anonymous), so the fallback is a neutral label rather
                  // than an invented person — this card previously
                  // hardcoded 'Daksh Sharma' for every user.
                  displayName.isEmpty ? 'Your profile' : displayName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // No user-facing ID concept exists in the data model; the
                  // former 'ID: VX-9832' was a design-mock string shown to
                  // every learner as if it were their account id.
                  activeMode == AppMode.exam
                      ? 'Exam Mode Active'
                      : 'Learn Mode Active',
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

  /// Streak and XP are live (`userProfileProvider` / `xpTotalProvider`).
  ///
  /// The previous version applied `streak > 0 ? streak : 18` and
  /// `xp > 0 ? … : '4.2k'`: a new learner with a genuine zero was shown
  /// fabricated non-zero progress, which is worse than a placeholder
  /// because it is indistinguishable from real data.
  ///
  /// Accuracy has NO source. There is no cross-mode accuracy metric in the
  /// architecture — Learn keeps per-concept mastery, Exam keeps per-section
  /// bands, and neither is a single app-wide percentage (§30 also keeps
  /// percentages out of learner-facing exam copy). It is therefore shown as
  /// unavailable instead of the hardcoded '88%'. Deriving one is a product
  /// decision, not something to invent here.
  Widget _buildMetricTrio(int streak, int xp) {
    final streakValue = streak == 1 ? '1 Day' : '$streak Days';
    final xpValue = xp >= 1000 ? '${(xp / 1000).toStringAsFixed(1)}k' : '$xp';

    return Row(
      children: [
        Expanded(
            child:
                _MetricTile(emoji: '🔥', value: streakValue, label: 'Streak')),
        const SizedBox(width: 10),
        Expanded(
            child: _MetricTile(emoji: '⚡', value: xpValue, label: 'XP Earned')),
        const SizedBox(width: 10),
        Expanded(
            child: _MetricTile(emoji: '🎯', value: '—', label: 'Accuracy')),
      ],
    );
  }

  Widget _buildMascotConfigCard(BuildContext context, String companionName,
      PersonalityMode? personalityMode) {
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
                  '$companionName (Duck)',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // Real personality setting. 'MENTOR' and
                // 'Mood: Focused & Ready' were both invented: the model has
                // no mood concept at all, and the only companion trait is
                // [PersonalityMode] (cheerleader / calm / fun), which is
                // null until the learner picks one.
                Text(
                  personalityMode == null
                      ? 'Personality not set yet'
                      : 'Personality: ${personalityMode.emoji} '
                          '${personalityMode.label}',
                  style: const TextStyle(
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

  /// Learn Mode languages the learner has actually started.
  ///
  /// This section used to render two fixed cards — "Hindi • Level 2 / 65%
  /// Unit 4 Completed" and "Tamil • Foundation / 30% Unit 1 Completed" —
  /// for every user, plus an "(8 Available)" count that did not match the
  /// 10-language catalogue. None of it came from storage.
  ///
  /// It is now driven by [kLearnLanguageCatalogue] filtered through
  /// [LearnProfileRepository.hasProfile], with the selected language marked
  /// active. Per-language completion percentage is deliberately NOT shown:
  /// no such figure exists in the Learn state model, and the script name is
  /// real catalogue metadata rather than an invented progress number.
  Widget _buildLearnProfilesSection(BuildContext context) {
    final repo = ref.watch(learnProfileRepositoryProvider);
    final selected = ref.watch(selectedLearnLanguageProvider);
    final started = kLearnLanguageCatalogue
        .where((spec) => repo.hasProfile(spec.language))
        .toList(growable: false);
    final remaining = kLearnLanguageCatalogue.length - started.length;

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
        if (started.isEmpty)
          VaaniXCard(
            padding: const EdgeInsets.all(14),
            child: const Text(
              'No Learn language started yet.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: VaaniXColors.textSecondaryLight,
              ),
            ),
          )
        else
          for (final spec in started) ...[
            VaaniXCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.englishName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          spec.scriptName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: VaaniXColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (spec.language == selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
          ],

        // Add Language — the count is the real remainder of the catalogue.
        OutlinedButton.icon(
          onPressed: () =>
              context.pushUnique(RouteNames.learnLanguageSelection),
          icon: const Icon(Icons.add, size: 16),
          label: Text(remaining > 0
              ? '+ Add New Language ($remaining available)'
              : '+ Add New Language'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: VaaniXRadius.borderMd),
            minimumSize: const Size(double.infinity, 42),
          ),
        ),
      ],
    );
  }

  /// The active syllabus for the active track, or null when there is no
  /// track, the syllabus is still loading, or it failed to load. Every
  /// caller renders an honest state for null rather than a placeholder
  /// course.
  CourseSyllabus? _activeSyllabus() {
    final trackId = ref.watch(examActiveTrackIdProvider).valueOrNull;
    if (trackId == null || trackId.isEmpty) return null;
    return ref.watch(courseSyllabusProvider(trackId)).valueOrNull;
  }

  String _activeTrackLabel() {
    final syllabus = _activeSyllabus();
    if (syllabus == null) return 'No exam track selected yet';
    final name = syllabus.courseNameEn.isNotEmpty
        ? syllabus.courseNameEn
        : syllabus.courseName;
    return name.isEmpty ? syllabus.subjectName : name;
  }

  String? _activeTrackClassLabel() {
    final syllabus = _activeSyllabus();
    return syllabus == null ? null : 'Class ${syllabus.klass}';
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
              // Real active track. The label and the pill were hardcoded
              // ('CBSE Class 10 Hindi Course A', 'Board 2026') and so lied
              // to every learner whose track differed — or who had none.
              // Both now come from the scope store plus the official
              // syllabus, with honest unset/loading states.
              Row(
                children: [
                  const Icon(Icons.school_rounded,
                      color: VaaniXColors.examIndigoAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _activeTrackLabel(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_activeTrackClassLabel() case final klassLabel?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VaaniXColors.examSurface,
                        borderRadius: VaaniXRadius.borderPill,
                      ),
                      child: Text(
                        klassLabel,
                        style: const TextStyle(
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

  /// Preference toggles.
  ///
  /// AUDIT NOTE — these three switches are local `setState` fields only.
  /// Nothing reads them, nothing persists them (they reset on every screen
  /// entry), and the app has no notification dependency or scheduler at
  /// all: there is no `flutter_local_notifications`, no notification
  /// service, nothing that could deliver a 7:30 PM reminder. Flipping them
  /// therefore has no effect whatsoever.
  ///
  /// They are kept visible but honestly captioned rather than silently
  /// pretending to configure delivery. Making them real needs a
  /// notification dependency, permission handling and a persisted
  /// preference store — new product surface, not an audit fix.
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
          const SizedBox(height: 4),
          const Text(
            'Reminders are not being delivered yet — these choices are not '
            'saved.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: VaaniXColors.textSecondaryLight,
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
              const Text(
                'Bundled offline',
                style: TextStyle(
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
          const SizedBox(height: 8),
          // HONESTY GUARD: there is no audio-waveform cache in this app.
          // AudioCadenceWaveform is a purely visual (animated bars) widget
          // and caches nothing. The previous "552 MB cached" readout and
          // its "Clear Cache" button were fabricated: the button only ran
          // setState(552 -> 120) and reported success for work never done.
          // Curriculum content ships as bundled assets, so there is
          // nothing user-clearable here until a real download cache exists.
          const Text(
            'This content ships with the app, so there is no separate '
            'download cache to clear.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: VaaniXColors.textSecondaryLight,
            ),
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
