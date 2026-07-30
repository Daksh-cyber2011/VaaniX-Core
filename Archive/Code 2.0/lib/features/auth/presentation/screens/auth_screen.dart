/// Auth Screen
///
/// Standalone auth screen (separate from onboarding).
/// Full Supabase auth wiring comes in the Auth milestone.
///
/// PRD Section 8.1 Screen 6 / Auth Layer.

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

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
                state: VanState.happy,
                size: 140,
                showSpeechBubble: true,
                dialogueText: "Let's create your account! 🦆",
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
              const Spacer(),
              PrimaryButton(
                label: 'Continue with Google',
                icon: const Icon(Icons.g_mobiledata_rounded,
                    color: Colors.white, size: 24),
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              PrimaryButton.secondary(
                label: 'Continue with Phone',
                icon: Icon(Icons.phone_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                onPressed: () {},
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
