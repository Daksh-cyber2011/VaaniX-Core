/// VaaniX AI — Learning Context Provider
///
/// Assembles the bounded [LearningContext] snapshot from REAL app state:
///   - adaptive next-action engine (progress feature)
///   - weak-area engine (progress feature)
///   - curriculum loader (learn feature)
///   - user profile (profile feature, day streak)
///
/// The ChatController stamps this snapshot onto every ConversationContext,
/// which carries it into the persona prompt via
/// [ConversationContext.learningContextFragment]. Nothing here leaves the
/// device except the final bounded fragment inside the prompt.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/ai/domain/learning_context.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';

/// Bounded snapshot of the learner's real curriculum state for the prompt.
///
/// Rebuilds whenever the underlying progress/adaptive state changes, so a
/// message sent right after completing a lesson already reflects it.
final learningContextProvider = Provider<LearningContext>((ref) {
  final curriculum =
      ref.watch(curriculumProvider).valueOrNull ?? const <Chapter>[];
  final next = ref.watch(adaptiveNextActionProvider);
  final weak = ref.watch(weakLessonsProvider);
  final completedCount = ref.watch(completedLessonIdsProvider).length;
  final streak = ref.watch(userProfileProvider).currentStreak;

  // Resolve the chapter the next action points into (lesson target or
  // exam target), so Van knows the learner's current chapter title.
  final lessons = <Lesson>[
    for (final Chapter chapter in curriculum) ...chapter.lessons,
  ];
  String? chapterTitle;
  String? lessonTitle;
  if (next.lessonId != null) {
    for (final Chapter chapter in curriculum) {
      for (final Lesson lesson in chapter.lessons) {
        if (lesson.id == next.lessonId) {
          chapterTitle = chapter.title;
          lessonTitle = lesson.title;
          break;
        }
      }
    }
  } else if (next.chapterId != null) {
    for (final chapter in curriculum) {
      if (chapter.id == next.chapterId) {
        chapterTitle = chapter.title;
        break;
      }
    }
  }

  return LearningContext.bounded(
    currentChapterTitle: chapterTitle,
    currentLessonTitle: lessonTitle,
    nextActionLabel: next.label,
    nextActionHint: next.subtitle,
    lessonsCompleted: completedCount,
    lessonsTotal: lessons.length,
    currentStreak: streak,
    weakLessonTitles: weak.map((l) => l.title).toList(growable: false),
  );
});
