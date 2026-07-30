/// Progress Screen
///
/// Streak calendar (heatmap), XP graph, chapter map,
/// Van's assessment text. Full impl: Progress milestone.
///
/// PRD Section 8.5

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/van_widget.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Progress', style: AppTextStyles.titleLarge()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VanWidget(
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
