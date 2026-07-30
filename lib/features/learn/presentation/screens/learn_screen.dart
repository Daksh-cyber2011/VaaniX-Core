/// Learn Screen — Lesson Tree

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VaaniXScaffold(
      title: 'Learn',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanWidget(
              state: VanState.thinking,
              size: 140,
              showSpeechBubble: true,
              dialogueText: 'Lessons are coming soon! 📚',
            ),
            const SizedBox(height: 24),
            Text(
              'Learn Mode',
              style: AppTextStyles.headlineSmall(),
            ),
            const SizedBox(height: 8),
            Text(
              'Structured Sanskrit lessons\ncoming in the next milestone.',
              style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
