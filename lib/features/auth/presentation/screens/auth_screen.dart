/// Auth Screen
///
/// Standalone auth screen (separate from onboarding). Wires email/password
/// sign-in & sign-up, Google OAuth, and Skip to [authRepositoryProvider],
/// surfacing loading and error states. Used both as a redirect target
/// (when Supabase is configured and the user is unauthenticated) and
/// inside the onboarding flow.
///
/// PRD Section 8.1 Screen 6 / Auth Layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';
import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/core/utils/result.dart';

import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canAuth => AppEnvironment.isSupabaseConfigured;

  Future<void> _signInWithEmail() async {
    await _runAuth(() => ref.read(authRepositoryProvider).signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  Future<void> _signUpWithEmail() async {
    await _runAuth(() => ref.read(authRepositoryProvider).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  Future<void> _signInWithGoogle() async {
    await _runAuth(() =>
        ref.read(authRepositoryProvider).signInWithOAuth(provider: 'google'));
  }

  /// Type-safe auth runner. Accepts a typed `Future<Result<T>>` action
  /// instead of `Future<dynamic>` — no more dynamic dispatch on result.
  Future<void> _runAuth<T>(Future<Result<T>> Function() action) async {
    // Basic client-side validation before hitting the repo.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        setState(() => _errorMessage = 'Please enter a valid email address.');
      }
      return;
    }
    if (password.length < 6) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Password must be at least 6 characters.');
      }
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final result = await action();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isBusy = false;
          // Surface a user-friendly message based on the failure type.
          _errorMessage = _friendlyMessage(failure);
        });
      },
      (_) {
        // On success the auth stream fires; the router redirect moves the
        // user to /home automatically. No explicit navigation needed.
        setState(() => _isBusy = false);
      },
    );
  }

  /// Map domain Failures to user-friendly strings.
  String _friendlyMessage(Failure failure) {
    if (failure is InvalidCredentialsFailure) {
      return 'Invalid email or password. Please try again.';
    }
    if (failure is ConflictFailure) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (failure is NotFoundFailure) {
      return 'No account found with this email. Try signing up first.';
    }
    if (failure is RateLimitFailure) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (failure is UnauthenticatedFailure) {
      return 'Please sign in to continue.';
    }
    return failure.message;
  }

  void _skip() {
    context.goNamed(RouteNames.homeName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              VanWidget(
                state: _isBusy ? VanState.thinking : VanState.happy,
                size: 120,
                showSpeechBubble: true,
                dialogueText:
                    _isBusy ? 'Hang on... 🦆' : "Let's get you started! 🦆",
              ),
              const SizedBox(height: 24),
              Text(
                'Create Your Account',
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Save your progress and keep Van safe.',
                style: AppTextStyles.bodyMedium(color: subtext),
                textAlign: TextAlign.center,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          style:
                              AppTextStyles.bodySmall(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ─── Email / Password Form ─────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_isBusy,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !_isBusy,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _isBusy
                        ? null
                        : () => setState(() {
                              _obscurePassword = !_obscurePassword;
                            }),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                label: 'Sign In',
                isLoading: _isBusy,
                icon: const Icon(Icons.login_rounded,
                    color: Colors.white, size: 20),
                onPressed: _isBusy ? null : _signInWithEmail,
              ),
              const SizedBox(height: 10),
              PrimaryButton.secondary(
                label: 'Sign Up',
                icon: Icon(Icons.person_add_alt_1_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                onPressed: _isBusy ? null : _signUpWithEmail,
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: AppTextStyles.bodySmall(color: subtext)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Google OAuth ──────────────────────────────────────────
              if (_canAuth) ...[
                PrimaryButton(
                  label: 'Continue with Google',
                  isLoading: _isBusy,
                  icon: const Icon(Icons.g_mobiledata_rounded,
                      color: Colors.white, size: 24),
                  onPressed: _isBusy ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 12),
              ],

              PrimaryButton.text(
                label: 'Skip for now',
                onPressed: _isBusy ? null : _skip,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
