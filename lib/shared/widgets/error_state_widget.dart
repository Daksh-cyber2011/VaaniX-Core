/// VaaniX Error State Widget
///
/// Standardized error view with retry button for failed network/data calls.
/// Fully theme-aware and reduced-motion friendly.
///
/// All user-facing error messages must be human-friendly — never expose raw
/// exception text, HTTP jargon, or stack traces. Use the [message] parameter
/// to describe what happened and what the student can do:
///
///   BAD:  'SocketException: Failed host lookup'
///   GOOD: 'Couldn\'t connect right now.\nYour progress is safe — try again
///          when you\'re online.'
///
/// An optional VAN companion ([showVan]) makes error states feel supportive
/// rather than alarming. Use [VanState.caring] (default) or [VanState.sad].
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
    this.showVan = false,
    this.vanState = VanState.caring,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  /// Set to [true] to show a caring VAN companion. Recommended for major
  /// error states (full-screen failures, network loss).
  final bool showVan;

  /// VAN's expression during the error. Defaults to [VanState.caring].
  final VanState vanState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = theme.colorScheme.error;
    final subtext = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVan) ...[
              VanWidget(
                state: vanState,
                size: AppDimens.vanSizeBubble + 24,
                showSpeechBubble: true,
                dialogueText: 'Don\'t worry — your progress is safe!',
              ),
              const SizedBox(height: AppDimens.space4),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppDimens.space5),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.errorContainerDark
                          : AppColors.errorContainerLight)
                      .withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: errorColor),
              ),
              const SizedBox(height: AppDimens.space5),
            ],
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space2),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(
                label: retryLabel,
                onPressed: onRetry,
                minimumSize: const Size(180, 48),
                icon: const Icon(Icons.refresh_rounded, size: 20,
                    color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
