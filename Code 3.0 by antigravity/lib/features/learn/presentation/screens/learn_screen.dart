/// Learn Screen — Lesson Tree
///
/// Chapter-based lesson tree with 6 lesson types.
/// Van reacts per answer. Full implementation: Learn milestone.
///
/// PRD Section 8.3

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Learn', style: AppTextStyles.titleLarge()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VanWidget(
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
              'Structured Sanskrit lessons\ncoming in the next update.',
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
