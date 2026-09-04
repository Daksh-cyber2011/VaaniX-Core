/// VaaniX Loading Indicator
///
/// Branded loading spinner using the theme-aware primary color, with an
/// optional supporting message. Always adapts to light/dark.
library;
import 'package:flutter/material.dart';

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
        ? theme.colorScheme.onSurface.withOpacity(0.64)
        : theme.colorScheme.onSurface.withOpacity(0.56);

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
            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
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

/// Full-screen loading overlay
class VaaniXLoadingOverlay extends StatelessWidget {
  const VaaniXLoadingOverlay({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: VaaniXLoadingIndicator(message: message),
      ),
    );
  }
}
