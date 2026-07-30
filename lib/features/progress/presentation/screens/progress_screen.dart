/// Progress Screen

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VaaniXScaffold(
      title: 'Progress',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanWidget(
              state: VanState.happy,
              size: 140,
              showSpeechBubble: true,
              dialogueText: 'Your journey starts now! ⭐',
            ),
            const SizedBox(height: 24),
            Text(
              'Progress',
              style: AppTextStyles.headlineSmall(),
            ),
            const SizedBox(height: 8),
            Text(
              'Streak calendars, XP graphs and\nchapter maps coming soon.',
              style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
