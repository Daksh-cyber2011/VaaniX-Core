/// Exam Mode 2.0 — Session XP Strip (M10)
///
/// The compact, honest outcome line shown on every session finish
/// screen: "+12 XP · 3-day streak". Reads [lastExamSessionOutcomeProvider]
/// (set by the gamification chain when a session finishes, cleared when
/// the next session starts) — never invents numbers, stays hidden when
/// nothing happened (all-zero outcome).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart';

class ExamSessionXpStrip extends ConsumerWidget {
  const ExamSessionXpStrip({super.key, this.trackId});

  /// When set, the strip only shows outcomes of this track (a stale
  /// outcome from another track is never shown — course isolation).
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(lastExamSessionOutcomeProvider);
    if (outcome == null) return const SizedBox.shrink();
    if (trackId != null && outcome.trackId != trackId) {
      return const SizedBox.shrink();
    }
    final headline = outcome.headline;
    if (headline.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded,
              size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              style: AppTextStyles.labelMedium(
                  color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
