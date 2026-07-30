/// Van Profile Screen

import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class VanProfileScreen extends StatelessWidget {
  const VanProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VaaniXScaffold(
      title: 'Van',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
