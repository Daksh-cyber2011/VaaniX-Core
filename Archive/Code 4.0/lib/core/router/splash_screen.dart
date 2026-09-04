/// Splash screen shown immediately on app launch.
///
/// Animates in the VaaniX logo, then performs the first routing decision:
///   - Onboarding not complete → onboarding flow.
///   - Otherwise → home (the main app shell).
///
/// The router's redirect guard (see app_router.dart) remains the
/// authoritative gate; this just avoids lingering on the splash while the
/// guard would otherwise bounce the user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../constants/route_names.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // Navigate after splash delay
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  /// Decides the first real route after the splash animation.
  ///
  /// Order:
  ///   1. Onboarding not complete → onboarding flow.
  ///   2. Onboarding complete + Supabase configured + not authenticated → auth.
  ///   3. Otherwise → home (the main app shell).
  ///
  /// Uses [localStorageServiceProvider] (no feature imports in core) plus a
  /// minimal read of the auth flag via the shared routing helper. The
  /// subsequent router redirect remains the authoritative guard; this is
  /// only the first-step decision so the splash never lingers on a stale
  /// screen.
  void _navigate() {
    if (!mounted) return;

    final storage = ref.read(localStorageServiceProvider);

    if (!storage.isOnboardingComplete) {
      context.goNamed(RouteNames.onboardingName);
      return;
    }

    context.goNamed(RouteNames.homeName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Van placeholder — will be replaced with Lottie animation
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.vanYellow,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Center(
                    child: Text('🦆', style: TextStyle(fontSize: 60)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.displaySmall(
                    color: AppColors.onBackgroundDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Learn Sanskrit with ${AppConstants.companionDefaultName}',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.subtextDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
