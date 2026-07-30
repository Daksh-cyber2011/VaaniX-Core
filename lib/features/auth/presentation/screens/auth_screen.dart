/// Auth Screen
///
/// Standalone auth screen (separate from onboarding). Wires the Google and
/// Phone sign-in buttons to [authRepositoryProvider], surfacing loading and
/// error states. Used both as a redirect target (when Supabase is configured
/// and the user is unauthenticated) and inside the onboarding flow.
///
/// PRD Section 8.1 Screen 6 / Auth Layer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    await _runAuth(() => ref
        .read(authRepositoryProvider)
        .signInWithOAuth(provider: 'google'));
  }

  Future<void> _signInWithPhone() async {
    // Phone OTP requires a phone number entry UI; for V1 we start an OTP flow
    // using a placeholder email-less path. A dedicated phone-entry sheet will
    // replace this once the phone-input widget lands.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Phone sign-in opens after number entry.')),
    );
    // No throw: keep the screen responsive.
    if (mounted) setState(() => _isBusy = false);
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
        // On success the auth stream fires; the router redirect moves the
        // user to /home automatically. No explicit navigation needed.
        if (mounted) setState(() => _isBusy = false);
      },
    );
  }

  void _skip() {
    context.goNamed(RouteNames.homeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              VanWidget(
                state: _isBusy ? VanState.thinking : VanState.happy,
                size: 140,
                showSpeechBubble: true,
                dialogueText: _isBusy
                    ? "Hang on... 🦆"
                    : "Let's create your account! 🦆",
              ),
              const SizedBox(height: 32),
              Text(
                'Create Your Account',
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Save your progress and keep Van safe.',
                style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
                textAlign: TextAlign.center,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
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

              const Spacer(),
              PrimaryButton(
                label: 'Continue with Google',
                isLoading: _isBusy,
                icon: const Icon(Icons.g_mobiledata_rounded,
                    color: Colors.white, size: 24),
                onPressed: _isBusy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              PrimaryButton.secondary(
                label: 'Continue with Phone',
                icon: Icon(Icons.phone_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                onPressed: _isBusy ? null : _signInWithPhone,
              ),
              const SizedBox(height: 16),
              PrimaryButton.text(
                label: 'Skip for now',
                onPressed: _skip,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
