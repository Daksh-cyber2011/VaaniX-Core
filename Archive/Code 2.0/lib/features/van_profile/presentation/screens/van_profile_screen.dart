/// Van Profile Screen
///
/// Outfit customization, earned accessories, personality mode selection.
/// Full impl: Van Profile milestone.
///
/// PRD Section 7 — Van Profile

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/widgets/van_widget.dart';

class VanProfileScreen extends StatelessWidget {
  const VanProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Van', style: AppTextStyles.titleLarge()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            VanWidget(
              state: VanState.funny,
              size: 180,
              showSpeechBubble: true,
              dialogueText: 'Customize my outfit soon! 🦆',
              onTap: () {},
            ),
            const SizedBox(height: 32),
            Text(
              'Van\'s Profile',
              style: AppTextStyles.headlineSmall(),
            ),
            const SizedBox(height: 8),
            Text(
              'Outfit customization and personality\nmodes coming in the next update.',
              style: AppTextStyles.bodyMedium(color: AppColors.subtextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
