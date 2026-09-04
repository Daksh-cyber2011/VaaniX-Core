/// VaaniX Offline Banner
///
/// A slim, calm status strip that appears whenever connectivity drops.
/// The app is offline-first, so the message reassures rather than alarms:
/// learning keeps working; only the AI conversation needs a connection.
///
/// Mount it once under the top of any screen body (or inside an app shell).
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/network/connectivity_service.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: isOnline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: margin,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.warningContainerDark
                    : AppColors.warningContainerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: isDark ? const Color(0xFFFFB74D) : AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You're offline. Lessons keep working - Van's AI chat needs a connection.",
                      style: AppTextStyles.bodySmall(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
