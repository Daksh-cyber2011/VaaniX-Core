/// Onboarding Screen — PageView Controller
///
/// The single screen that hosts all 6 onboarding pages in a
/// non-swipeable PageView (user must press Continue to advance).
///
/// Pages:
///   0 — Name Van          (ob_name_page.dart)
///   1 — Personality Mode  (ob_personality_page.dart)
///   2 — Subject Setup     (ob_subject_page.dart)
///   3 — Daily Goal        (ob_goal_page.dart)
///   4 — Account Creation  (ob_auth_page.dart)
///   5 — Nest Reveal       (ob_nest_reveal_page.dart)
///
/// The splash is already built (splash_screen.dart) and counts as
/// PRD Section 8.1 Screen 1. This screen handles Screens 2–7.
///
/// PRD Section 8.1

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/ob_auth_page.dart';
import '../widgets/ob_goal_page.dart';
import '../widgets/ob_name_page.dart';
import '../widgets/ob_nest_reveal_page.dart';
import '../widgets/ob_personality_page.dart';
import '../widgets/ob_subject_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;

  static const _pages = [
    ObNamePage(),
    ObPersonalityPage(),
    ObSubjectPage(),
    ObGoalPage(),
    ObAuthPage(),
    ObNestRevealPage(),
  ];

  static const _totalPages = 6;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingProvider).currentPage;

    // When state changes (notifier calls nextPage/previousPage),
    // animate the PageController to match.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != currentPage) {
        _pageController.animateToPage(
          currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: back button + page indicators ──────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Back button (hidden on first page)
                  AnimatedOpacity(
                    opacity: currentPage > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: currentPage > 0
                          ? () => ref
                              .read(onboardingProvider.notifier)
                              .previousPage()
                          : null,
                      iconSize: 20,
                    ),
                  ),

                  // Page indicators
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (i) {
                        return _PageDot(
                          isActive: i == currentPage,
                          isPassed: i < currentPage,
                        );
                      }),
                    ),
                  ),

                  // Balance the back button
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Page content ────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                // Disable manual swipe — user must tap Continue
                physics: const NeverScrollableScrollPhysics(),
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small dot indicator for the current page position.
class _PageDot extends StatelessWidget {
  const _PageDot({
    required this.isActive,
    required this.isPassed,
  });

  final bool isActive;
  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : isPassed
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.borderLight,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
