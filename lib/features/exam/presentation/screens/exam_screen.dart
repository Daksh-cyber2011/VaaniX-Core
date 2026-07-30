/// Exam Screen — Practice Quiz / Mock Test

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VaaniXScaffold(
      title: 'Exam',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VanWidget(
              state: VanState.focus,
              size: 140,
              showSpeechBubble: true,
              dialogueText: 'Exam mode is coming! 🎯',
            ),
            const SizedBox(height: 24),
            Text(
              'Exam Mode',
              style: AppTextStyles.headlineSmall(),
            ),
            const SizedBox(height: 8),
            Text(
              'Practice quizzes and mock tests\ncoming in the next milestone.',
              style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
