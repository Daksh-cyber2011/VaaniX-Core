/// Quiz Bank Single-Source Tests (Phase 2)
///
/// The exam bank and the adaptive quiz-id maps MUST both derive from the
/// JSON curriculum asset (assets/curriculum/v1.json). These tests pin the
/// contract:
///   1. the JSON bank and the compiled-in Dart fallback are content-equal
///      (guarantees the runtime switch to JSON changes NO question content),
///   2. the adaptive id maps derived from the bank cover every chapter with
///      quizzes and use the same `quiz_<chapter>_<difficulty>` space as
///      ExamConfig,
///   3. the async exam session serves the deterministic selection, restarts
///      cleanly, and fails loudly on an empty config.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON bank == Dart fallback (content unchanged)', () {
    test('loadAllQuizQuestions returns exactly the Dart fallback bank',
        () async {
      final jsonBank = await loadAllQuizQuestions();
      final dartBank = chapterQuizzes.values.expand((q) => q).toList();

      expect(jsonBank.length, dartBank.length,
          reason: 'bank size must not change with the single-source switch');
      final jsonById = {for (final q in jsonBank) q.id: q};
      for (final q in dartBank) {
        final twin = jsonById[q.id];
        expect(twin, isNotNull, reason: '${q.id} missing from JSON bank');
        expect(twin, q, reason: '${q.id} content must be identical');
      }
    });

    test('every chapter with lessons has its quiz group in the JSON bank',
        () async {
      final jsonBank = await loadAllQuizQuestions();
      final chaptersWithQuizzes = jsonBank.map((q) => q.chapterId).toSet();
      for (final chapter in sanskritCurriculum) {
        expect(chaptersWithQuizzes.contains(chapter.id), isTrue,
            reason: '${chapter.id} has lessons but no JSON quiz group');
      }
    });
  });

  group('adaptive id maps derive from the bank', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      // Settle the real asset loads (single source) before reading maps.
      await container.read(curriculumProvider.future);
      await container.read(quizBankProvider.future);
    });

    tearDown(() => container.dispose);

    test('catalog uses the ExamConfig quizId space', () {
      final ids = container.read(quizIdCatalogProvider);
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(
          RegExp(r'^quiz_ch_[a-z]+_(beginner|intermediate|advanced)$')
              .hasMatch(id),
          isTrue,
          reason: '$id must be a chapter/difficulty quiz id',
        );
      }
      // Spot-check against ExamConfig for one known chapter.
      expect(
        ids.contains(const ExamConfig(
          chapterId: 'ch_alphabet',
          difficulty: Difficulty.beginner,
        ).quizId),
        isTrue,
      );
    });

    test('per-chapter map covers every chapter that has questions', () {
      final byChapter = container.read(quizIdsByChapterProvider);
      final bank = container.read(quizBankProvider).valueOrNull ?? const [];
      final chaptersInBank = bank.map((q) => q.chapterId).toSet();
      expect(byChapter.keys.toSet(), chaptersInBank);
      for (final entry in byChapter.entries) {
        expect(entry.value.toSet().length, entry.value.length,
            reason: '${entry.key} quiz ids must be de-duplicated');
      }
    });
  });

  group('async exam session', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await container.read(quizBankProvider.future);
    });

    tearDown(() => container.dispose);

    test('serves the deterministic selection for a config', () async {
      const config = ExamConfig(
          chapterId: 'ch_alphabet', difficulty: Difficulty.beginner);
      // First read resolves the session.
      await container.read(examQuizProvider(config).future);
      final controller = container.read(examQuizProvider(config).notifier);

      final expected = selectExamQuestions(
        container.read(quizBankProvider).valueOrNull ?? const [],
        chapterId: config.chapterId,
        difficulty: config.difficulty,
      );
      expect(controller.total, expected.length);
      expect(controller.current.id, expected.first.id);
    });

    test('restart yields a fresh attempt for the same config', () async {
      const config = ExamConfig(
          chapterId: 'ch_alphabet', difficulty: Difficulty.beginner);
      await container.read(examQuizProvider(config).future);
      final notifier = container.read(examQuizProvider(config).notifier);

      notifier.select(0);
      notifier.submit();
      notifier.next();
      expect(
        container.read(examQuizProvider(config)).valueOrNull!.currentIndex,
        1,
      );

      notifier.restart();
      final fresh = container.read(examQuizProvider(config)).valueOrNull!;
      expect(fresh.currentIndex, 0);
      expect(fresh.score, 0);
      expect(fresh.answered, isFalse);
      expect(fresh.finished, isFalse);
    });

    test('a config with no questions stays empty (UI shows the empty state)',
        () async {
      // ch_alphabet authors no advanced questions — an empty-bank config
      // must surface total == 0, never a crash on build.
      const config = ExamConfig(
          chapterId: 'ch_alphabet', difficulty: Difficulty.advanced);
      await container.read(examQuizProvider(config).future);
      final controller = container.read(examQuizProvider(config).notifier);
      expect(controller.total, 0);
      expect(
        () => controller.current,
        throwsStateError,
        reason: 'current must fail LOUDLY (clear StateError), not clamp',
      );
    });
  });
}
