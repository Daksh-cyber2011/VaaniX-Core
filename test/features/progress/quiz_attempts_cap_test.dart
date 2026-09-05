/// Attempt-History Cap + Session-Snapshot Reset Tests (Phase 2)
///
/// The per-quizId attempt history used to grow without bound (append-only).
/// It is now capped at AppConstants.maxAttemptsPerQuiz with the all-time
/// best attempt ALWAYS retained, and a full progress reset purges the
/// ephemeral practice-session snapshots as well.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

QuizResult _attempt(String quizId, int score, int total) => QuizResult(
      quizId: quizId,
      score: score,
      total: total,
      xpEarned: 0,
      completedAt: DateTime.now(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('capAttempts (pure trimmer)', () {
    test('histories under the cap are untouched', () {
      final attempts = [
        _attempt('q', 1, 5),
        _attempt('q', 3, 5),
      ];
      expect(LocalProgressRepository.capAttempts(attempts), same(attempts));
    });

    test('trims to the cap, preserves order and the NEWEST attempt', () {
      final attempts = [
        for (var i = 0; i < AppConstants.maxAttemptsPerQuiz + 5; i++)
          _attempt('q', i % 3, 5),
      ];
      final capped = LocalProgressRepository.capAttempts(attempts);

      expect(capped.length, AppConstants.maxAttemptsPerQuiz);
      // Newest entry (the last one appended) must survive.
      expect(capped.last, attempts.last);
      // Order preserved: capped must be an in-order subsequence of attempts.
      var cursor = 0;
      for (final kept in capped) {
        while (cursor < attempts.length && !identical(attempts[cursor], kept)) {
          cursor++;
        }
        expect(cursor < attempts.length, isTrue,
            reason: 'capped entries must keep their original order');
        cursor++;
      }
      // The all-time best VALUE survives the trim.
      expect(capped.any((a) => a.score == 2), isTrue);
    });

    test('the all-time best attempt survives aggressive trimming', () {
      // Best is the OLDEST attempt (score 5/5); everything after is 0.
      final attempts = [
        _attempt('q', 5, 5),
        for (var i = 0; i < AppConstants.maxAttemptsPerQuiz + 3; i++)
          _attempt('q', 0, 5),
      ];
      final capped = LocalProgressRepository.capAttempts(attempts);

      expect(capped.length, AppConstants.maxAttemptsPerQuiz);
      expect(capped.first.score, 5,
          reason: 'the all-time best (oldest entry) must be retained');
      expect(capped.last, attempts.last,
          reason: 'the newest attempt must be retained');
    });

    test('an all-tied history trims from the oldest but keeps the best VALUE',
        () {
      final attempts = [
        for (var i = 0; i < AppConstants.maxAttemptsPerQuiz + 2; i++)
          _attempt('q', 2, 5),
      ];
      final capped = LocalProgressRepository.capAttempts(attempts);
      expect(capped.length, AppConstants.maxAttemptsPerQuiz);
      expect(capped.every((a) => a.score == 2), isTrue);
    });
  });

  group('repository-level cap + reset purge', () {
    late ProviderContainer container;
    late LocalProgressRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      repo = LocalProgressRepository(
        container.read(localStorageServiceProvider),
      );
    });

    tearDown(() => container.dispose);

    test('completeQuiz caps persisted history at the configured maximum',
        () async {
      const quizId = 'quiz_cap_test_beginner';
      for (var i = 0; i < AppConstants.maxAttemptsPerQuiz + 7; i++) {
        await repo.completeQuiz(quizId: quizId, score: i % 4, total: 4);
      }
      final history =
          repo.getQuizAttempts(quizId).fold((_) => <QuizResult>[], (v) => v);
      expect(history.length, AppConstants.maxAttemptsPerQuiz);
      // Best across the whole run: score 3/4 — must still be present.
      expect(history.map((a) => a.score).reduce((a, b) => a > b ? a : b), 3);
      // Newest attempt survives.
      expect(history.last.score, (AppConstants.maxAttemptsPerQuiz + 6) % 4);
    });

    test('reset purges in-progress exercise session snapshots too', () async {
      final storage = container.read(localStorageServiceProvider);
      await storage.setString(
        'exercise_session_ls_any_lesson',
        jsonEncode({'v': 1, 'currentIndex': 2, 'score': 1}),
      );
      expect(storage.getString('exercise_session_ls_any_lesson'), isNotNull);

      await repo.reset();

      expect(storage.getString('exercise_session_ls_any_lesson'), isNull,
          reason: 'ephemeral practice snapshots are progress state');
    });
  });
}
