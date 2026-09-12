/// Review Challenge — pure domain tests (Milestone 7)
///
/// The deterministic daily picker and the once-per-day claim gate,
/// verified without Flutter, Riverpod or storage.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/review_challenge.dart';

Lesson _lesson(String id, {int order = 0}) => Lesson(
      id: id,
      title: 'Lesson $id',
      chapterId: 'ch',
      order: order,
    );

void main() {
  group('reviewChallengeSourceId', () {
    test('is date-keyed so a NEW day pays again (exactly once)', () {
      expect(reviewChallengeSourceId('2026-09-11'), 'review_2026-09-11');
      expect(reviewChallengeSourceId('2026-09-12'),
          isNot(reviewChallengeSourceId('2026-09-11')));
    });
  });

  group('ReviewChallenge.remaining', () {
    test('clamps between 0 and the authored total', () {
      const over = ReviewChallenge(
        lesson: Lesson(id: 'l1', title: 'L1', chapterId: 'ch'),
        masteredCount: 9,
        totalCount: 4,
      );
      expect(over.remaining, 0);

      const under = ReviewChallenge(
        lesson: Lesson(id: 'l1', title: 'L1', chapterId: 'ch'),
        masteredCount: 2,
        totalCount: 4,
      );
      expect(under.remaining, 2);
    });
  });

  group('pickDailyReviewChallenge', () {
    test('empty weak-lesson list → no challenge (nothing worth reviewing)',
        () {
      expect(
        pickDailyReviewChallenge(
          const [],
          (_) => 0,
          (_) => 3,
        ),
        isNull,
      );
    });

    test('skips lessons with no authored exercises, picks the FIRST real one',
        () {
      final lessons = [_lesson('stub'), _lesson('weak1'), _lesson('weak2')];
      final challenge = pickDailyReviewChallenge(
        lessons,
        (lesson) => lesson.id == 'weak1' ? 1 : 0,
        (lesson) => lesson.id == 'stub' ? 0 : 3,
      );
      expect(challenge, isNotNull);
      expect(challenge!.lesson.id, 'weak1',
          reason: 'curriculum order decides — the first weak lesson wins');
      expect(challenge.masteredCount, 1);
      expect(challenge.totalCount, 3);
      expect(challenge.remaining, 2);
    });

    test('null when every candidate has zero authored exercises', () {
      final lessons = [_lesson('stub1'), _lesson('stub2')];
      expect(
        pickDailyReviewChallenge(
          lessons,
          (_) => 0,
          (_) => 0,
        ),
        isNull,
        reason: 'the challenge is always real review of real content',
      );
    });

    test('fully-mastered lessons never appear as weak lessons, so the '
        'picker mirrors the adaptive engine contract', () {
      // The caller (dailyReviewChallengeProvider) only passes lessons from
      // weakLessonsProvider; a fully mastered lesson would never arrive.
      // This test pins the pure behaviour: whatever arrives first wins.
      final lessons = [_lesson('a'), _lesson('b')];
      final challenge = pickDailyReviewChallenge(
        lessons,
        (_) => 0,
        (_) => 2,
      );
      expect(challenge!.lesson.id, 'a');
    });
  });

  group('completesReviewChallenge', () {
    const challenge = ReviewChallenge(
      lesson: Lesson(id: 'weak1', title: 'W1', chapterId: 'ch'),
      masteredCount: 2,
      totalCount: 4,
    );

    test('no challenge → no completion', () {
      expect(
        completesReviewChallenge(
          challenge: null,
          lessonId: 'weak1',
          masteredAfterSession: 4,
          totalAuthored: 4,
        ),
        isFalse,
      );
    });

    test('a different lesson than the challenge never completes it', () {
      expect(
        completesReviewChallenge(
          challenge: challenge,
          lessonId: 'weak2',
          masteredAfterSession: 4,
          totalAuthored: 4,
        ),
        isFalse,
      );
    });

    test('incomplete mastery does not pay the bonus', () {
      expect(
        completesReviewChallenge(
          challenge: challenge,
          lessonId: 'weak1',
          masteredAfterSession: 3,
          totalAuthored: 4,
        ),
        isFalse,
      );
    });

    test('zero authored exercises is a guard, never a payout', () {
      expect(
        completesReviewChallenge(
          challenge: challenge,
          lessonId: 'weak1',
          masteredAfterSession: 0,
          totalAuthored: 0,
        ),
        isFalse,
      );
    });

    test('full mastery of the challenge lesson completes it', () {
      expect(
        completesReviewChallenge(
          challenge: challenge,
          lessonId: 'weak1',
          masteredAfterSession: 4,
          totalAuthored: 4,
        ),
        isTrue,
      );
      // Over-completing (defensive save) still counts.
      expect(
        completesReviewChallenge(
          challenge: challenge,
          lessonId: 'weak1',
          masteredAfterSession: 6,
          totalAuthored: 4,
        ),
        isTrue,
      );
    });
  });
}
