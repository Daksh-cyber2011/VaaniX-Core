/// VaaniX V1 Design System — Animated Mode Switch
///
/// Sliding segmented pill toggle between EXAM MODE ("Tactical Cockpit")
/// and LEARN MODE ("The Sanctuary").
///
/// Features:
/// - Smooth animated sliding thumb
/// - Tactile haptic feedback
/// - Mode-aware accent colors (Indigo/Violet for Learn, Cyan/Cobalt for Exam)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/providers/app_mode_provider.dart';
import 'package:vaanix_app/core/theme/vaanix_colors.dart';
import 'package:vaanix_app/core/theme/vaanix_radius.dart';

class VaaniXModeSwitch extends ConsumerWidget {
  const VaaniXModeSwitch({
    super.key,
    this.onChanged,
    this.compact = false,
  });

  final ValueChanged<AppMode>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(appModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        activeMode == AppMode.exam;

    final bgTrackColor = isDark
        ? VaaniXColors.examSurfaceCard
        : VaaniXColors.learnSurfaceElevated;
    final borderColor = isDark
        ? VaaniXColors.examBorder
        : VaaniXColors.learnBorder;

    return Container(
      height: compact ? 36 : 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgTrackColor,
        borderRadius: VaaniXRadius.borderPill,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = (constraints.maxWidth - 2) / 2;
          final isExam = activeMode == AppMode.exam;

          return Stack(
            children: [
              // Sliding Animated Thumb
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment:
                    isExam ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isExam
                        ? VaaniXColors.examCyanAccent
                        : VaaniXColors.learnPrimaryViolet,
                    borderRadius: VaaniXRadius.borderPill,
                    boxShadow: [
                      BoxShadow(
                        color: (isExam
                                ? VaaniXColors.examCyanAccent
                                : VaaniXColors.learnPrimaryViolet)
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Segment Buttons Row
              Row(
                children: [
                  Expanded(
                    child: _ModeSegment(
                      title: 'EXAM',
                      icon: Icons.bolt_rounded,
                      isActive: isExam,
                      activeColor: const Color(0xFF090D16),
                      inactiveColor: isDark
                          ? VaaniXColors.textSecondaryDark
                          : VaaniXColors.textSecondaryLight,
                      onTap: () {
                        if (!isExam) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(appModeProvider.notifier)
                              .setMode(AppMode.exam);
                          onChanged?.call(AppMode.exam);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _ModeSegment(
                      title: 'LEARN',
                      icon: Icons.menu_book_rounded,
                      isActive: !isExam,
                      activeColor: Colors.white,
                      inactiveColor: isDark
                          ? VaaniXColors.textSecondaryDark
                          : VaaniXColors.textSecondaryLight,
                      onTap: () {
                        if (isExam) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(appModeProvider.notifier)
                              .setMode(AppMode.learn);
                          onChanged?.call(AppMode.learn);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? activeColor : inactiveColor,
            letterSpacing: 0.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 5),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
