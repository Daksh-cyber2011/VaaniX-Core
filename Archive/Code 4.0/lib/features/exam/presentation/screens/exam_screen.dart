/// Exam Screen — Practice Quiz / Mock Test
///
/// Exam mode with Practice Quiz, Chapter Test, Mock Test (timed),
/// Weak Area Drill, and Daily Quiz. Full impl: Exam milestone.
///
/// PRD Section 8.4

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Exam', style: AppTextStyles.titleLarge()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VanWidget(
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
              'Practice quizzes and mock tests\ncoming in the next update.',
              style:
                  AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
