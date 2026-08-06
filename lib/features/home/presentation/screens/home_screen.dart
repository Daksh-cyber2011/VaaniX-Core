/// Home Screen — The Nest
///
/// Van's cozy learning space. Shows the animated Van companion, the daily
/// greeting, streak and XP badges (read from [userProfileProvider] and
/// [xpTotalProvider]), and the primary "Start Today's Lesson" CTA which
/// navigates to the Learn tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Record today's activity so the streak stays current whenever the Nest
    // is opened. Fire-and-forget; the provider handles persistence.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).recordDailyActivity();
    });
  }

  void _startLesson() {
    // Jump to the Learn branch of the shell.
    context.go(RouteNames.learn);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider);
    final xp = ref.watch(xpTotalProvider);

    final companionName = profile.resolvedCompanionName;
    final streak = profile.currentStreak;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'सुप्रभातम्'
        : (hour < 17 ? 'शुभ अपराह्नः' : 'शुभ सायं');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar: Streak + XP + Avatar ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (streak > 0) ...[
                    StreakBadge(streakCount: streak),
                    const SizedBox(width: 10),
                  ],
                  XpBadge(xpTotal: xp),
                  const Spacer(),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ─── The Nest background + Van ────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.nestWarmLight,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        '$greeting!',
                        style: AppTextStyles.headlineSmall(
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    VanWidget(
                      state: VanState.happy,
                      size: 200,
                      showSpeechBubble: true,
                      dialogueText:
                          "Ready to learn with $companionName, $greeting! 🦆",
                    ),
                  ],
                ),
              ),
            ),

            // ─── CTA Button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                onPressed: _startLesson,
                icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
                label: "Start Today's Lesson",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
