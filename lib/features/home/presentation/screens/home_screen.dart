/// Home Screen — The Nest
///
/// Van's cozy learning space. Shows the animated Van companion,
/// daily greeting, streak, XP, and the primary "Start Today's Lesson" CTA.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/streak_badge.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import 'package:vaanix_app/shared/widgets/xp_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final storage = ref.watch(localStorageServiceProvider);
    final companionName = storage.companionName;
    final streak = storage.currentStreak;

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
                  StreakBadge(streakCount: streak > 0 ? streak : 1),
                  const SizedBox(width: 10),
                  const XpBadge(xpTotal: 0),
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
                    VanWidget(
                      state: VanState.happy,
                      size: 200,
                      showSpeechBubble: true,
                      dialogueText: "Ready to start learning with $companionName? 🦆",
                    ),
                  ],
                ),
              ),
            ),

            // ─── CTA Button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                onPressed: () {},
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
