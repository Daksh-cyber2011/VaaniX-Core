/// Onboarding Page 5 — Account Creation
///
/// UI shell for auth (Phone OTP / Google Sign-In).
/// When Supabase is configured, pressing Google/Phone triggers the real
/// auth flow; on success the auth stream fires and the router redirect moves
/// the user forward automatically. When Supabase is not configured, the
/// buttons skip (offline-first).
/// Per PRD Section 8.1 Screen 6.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ObAuthPage extends ConsumerStatefulWidget {
  const ObAuthPage({super.key});

  @override
  ConsumerState<ObAuthPage> createState() => _ObAuthPageState();
}

class _ObAuthPageState extends ConsumerState<ObAuthPage> {
  bool _isBusy = false;
  String? _errorMessage;

  bool get _canAuth => AppEnvironment.isSupabaseConfigured;

  Future<void> _signInWithGoogle() async {
    if (!_canAuth) {
      ref.read(onboardingProvider.notifier).skipAuth();
      return;
    }
    await _runAuth(() => ref
        .read(authRepositoryProvider)
        .signInWithOAuth(provider: 'google'));
  }

  Future<void> _signInWithPhone() async {
    if (!_canAuth) {
      ref.read(onboardingProvider.notifier).skipAuth();
      return;
    }
    // Phone OTP requires a phone number entry UI. V1 delegates to skip
    // until the phone-input widget lands; the full OTP flow will be
    // wired here once the UI is ready.
    ref.read(onboardingProvider.notifier).skipAuth();
  }

  Future<void> _runAuth(Future<dynamic> Function() action) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    final result = await action();
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _errorMessage = failure.message;
          });
        }
      },
      (_) {
        // On success the auth stream fires; the router redirect and/or
        // onboarding notifier handle forward navigation. No explicit
        // skip needed.
        if (mounted) setState(() => _isBusy = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(onboardingProvider.notifier);
    final companionName = ref.watch(onboardingProvider).resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          VanWidget(
            state: _isBusy ? VanState.thinking : VanState.happy,
            size: 140,
            showSpeechBubble: true,
            dialogueText: _isBusy
                ? 'Signing you in...'
                : 'Let\'s save your progress, $companionName and I are ready! 🦆',
          ),

          const SizedBox(height: 36),

          Text(
            'Create your account',
            style: AppTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your streak and progress are stored safely.',
            style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
            textAlign: TextAlign.center,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          _SocialButton(
            icon: _GoogleIcon(),
            label: 'Continue with Google',
            onPressed: _isBusy ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 12),

          _SocialButton.outlined(
            icon: const Icon(Icons.phone_outlined, size: 20),
            label: 'Continue with Phone',
            onPressed: _isBusy ? null : _signInWithPhone,
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or',
                    style: AppTextStyles.bodySmall(
                        color: AppColors.subtextLight)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),

          PrimaryButton.text(
            label: 'Skip for now',
            onPressed: _isBusy ? null : notifier.skipAuth,
          ),

          const SizedBox(height: 16),
          Text(
            'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
            style: AppTextStyles.bodySmall(color: AppColors.subtextLight),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    this.onPressed,
  }) : _outlined = false;

  const _SocialButton.outlined({
    required this.icon,
    required this.label,
    this.onPressed,
  }) : _outlined = true;

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.borderLight, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.labelLarge()),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: theme.colorScheme.primary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(label,
              style: AppTextStyles.labelLarge(color: Colors.white)),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
