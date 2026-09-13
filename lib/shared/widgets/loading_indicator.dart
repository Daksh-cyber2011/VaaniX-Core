/// VaaniX Loading Indicator
///
/// Branded loading spinner using the theme-aware primary color, with an
/// optional supporting message. Always adapts to light/dark.
///
/// Variants:
///   [VaaniXLoadingIndicator] — compact spinner + optional message
///   [VaaniXLoadingOverlay]   — full-screen loading page with warm bg
///   [VanLoadingState]        — VAN companion with loading strip (for major
///                              async states like plan generation, AI calls)
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class VaaniXLoadingIndicator extends StatelessWidget {
  const VaaniXLoadingIndicator({
    super.key,
    this.message,
    this.size = 40.0,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtext = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.64)
        : theme.colorScheme.onSurface.withValues(alpha: 0.56);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            // Announced by screen readers; the visual spinner alone is silent.
            semanticsLabel: message ?? 'Loading',
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Full-screen loading overlay with warm branded background and optional
/// VAN companion. Used for major async operations (plan generation, diagnostics).
class VaaniXLoadingOverlay extends StatelessWidget {
  const VaaniXLoadingOverlay({
    super.key,
    this.message,
    this.showVan = false,
    this.vanMessage,
  });

  final String? message;

  /// Whether to show VAN with a thinking animation. Use for AI/plan
  /// operations where the wait feels personal.
  final bool showVan;

  /// Message to show in Van's speech bubble when [showVan] is true.
  final String? vanMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: showVan
              ? _VanLoading(message: message, vanMessage: vanMessage)
              : VaaniXLoadingIndicator(message: message),
        ),
      ),
    );
  }
}

/// VAN-based loading widget for major async operations.
/// VAN shows the "thinking" expression while a subtle spinner confirms work.
class VanLoadingState extends StatelessWidget {
  const VanLoadingState({
    super.key,
    this.message = 'Getting things ready…',
    this.vanMessage,
  });

  final String message;
  final String? vanMessage;

  @override
  Widget build(BuildContext context) => _VanLoading(
        message: message,
        vanMessage: vanMessage,
      );
}

class _VanLoading extends StatelessWidget {
  const _VanLoading({this.message, this.vanMessage});

  final String? message;
  final String? vanMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VanWidget(
            state: VanState.thinking,
            size: AppDimens.vanSizeHero,
            showSpeechBubble: vanMessage != null,
            dialogueText: vanMessage,
            isLoading: vanMessage == null,
          ),
          const SizedBox(height: AppDimens.space5),
          if (message != null)
            Text(
              message!,
              style: AppTextStyles.bodyMedium(color: subtext),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: AppDimens.space4),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              semanticsLabel: message ?? 'Loading',
            ),
          ),
        ],
      ),
    );
  }
}
