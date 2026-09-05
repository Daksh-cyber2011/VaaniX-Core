/// Onboarding Page 5 — Account Creation
///
/// UI shell for auth (Phone OTP / Google Sign-In).
/// Full Supabase wiring done in the Auth milestone.
/// For now, shows the UI and allows skipping to next page.
/// Per PRD Section 8.1 Screen 6.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';
import '../providers/onboarding_provider.dart';

class ObAuthPage extends ConsumerWidget {
  const ObAuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingProvider.notifier);
    final companionName = ref.watch(onboardingProvider).resolvedName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          VanWidget(
            state: VanState.happy,
            size: 140,
            showSpeechBubble: true,
            dialogueText:
                'Let\'s save your progress, $companionName and I are ready! 🦆',
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

          const SizedBox(height: 36),

          // ── Google Sign-In ─────────────────────────────────────
          _SocialButton(
            icon: _GoogleIcon(),
            label: 'Continue with Google',
            onPressed: () {
              // TODO(Auth milestone): implement Google OAuth via Supabase
              notifier.skipAuth();
            },
          ),
          const SizedBox(height: 12),

          // ── Phone OTP ──────────────────────────────────────────
          _SocialButton.outlined(
            icon: const Icon(Icons.phone_outlined, size: 20),
            label: 'Continue with Phone',
            onPressed: () {
              // TODO(Auth milestone): implement Phone OTP via Supabase
              notifier.skipAuth();
            },
          ),

          const SizedBox(height: 24),

          // ── Divider ────────────────────────────────────────────
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

          // ── Skip ───────────────────────────────────────────────
          PrimaryButton.text(
            label: 'Skip for now',
            onPressed: notifier.skipAuth,
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
    required this.onPressed,
  }) : _outlined = false;

  const _SocialButton.outlined({
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : _outlined = true;

  final Widget icon;
  final String label;
  final VoidCallback onPressed;
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

/// Simple "G" icon as SVG-free placeholder for Google button.
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
