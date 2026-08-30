/// VaaniX VAN Speech Strip
///
/// A compact companion line for surfaces where the full-size VAN would crowd
/// the task: lesson introductions, exam preparation, results, error and
/// offline moments. VAN speaks from the left edge; the message sits in a
/// soft speech container that mirrors the full-size speech bubble language.
///
/// The avatar is rendered through [VanWidget] at strip size so the visual
/// stays replaceable when final VAN artwork lands.
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/van/van.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class VanSpeechStrip extends StatelessWidget {
  const VanSpeechStrip({
    super.key,
    required this.message,
    this.state = VanState.idle,
    this.isLoading = false,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  final String message;
  final VanState state;
  final bool isLoading;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: Semantics(
        label: 'Van says: $message',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            VanWidget(
              size: 44,
              state: state,
              isLoading: isLoading,
              onTap: onTap,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryContainerDark
                      : AppColors.primaryContainerLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  message,
                  style: AppTextStyles.vanDialogue(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
