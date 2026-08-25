import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/progress/domain/gamification.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Lesson _lesson(String id, {int order = 0, String chapterId = 'ch'}) => Lesson(
      id: id,
      title: 'Lesson $id',
      chapterId: chapterId,
      order: order,
    );

Chapter _chapter(String id, List<Lesson> lessons, {int order = 0}) =>
    Chapter(id: id, title: 'Chapter $id', lessons: lessons, order: order);

void main() {
  group('level curve', () {
    test('level 1 starts at 0 XP', () {
      expect(cumulativeXpForLevel(1), 0);
      expect(levelFromXp(0), 1);
      expect(levelFromXp(50), 1);
      expect(levelFromXp(99), 1);
    });

    test('boundaries are exact', () {
      expect(cumulativeXpForLevel(2), 100);
      expect(levelFromXp(100), 2);
      expect(levelFromXp(299), 2);
      expect(cumulativeXpForLevel(3), 300);
      expect(levelFromXp(300), 3);
      expect(levelFromXp(599), 3);
      expect(cumulativeXpForLevel(4), 600);
      expect(levelFromXp(600), 4);
    });

    test('xpIntoLevel and levelProgress stay in range and climb', () {
      expect(xpIntoLevel(0), 0);
      expect(xpIntoLevel(150), 50);
      expect(levelProgress(0), 0);
      expect(levelProgress(100), 0.0); // fresh into level 2 (spans 100-299)
      expect(levelProgress(150), closeTo(0.25, 0.01)); // 50/200
      expect(levelProgress(199), closeTo(0.495, 0.01));
      expect(levelProgress(200), closeTo(0.5, 0.01));
      expect(levelProgress(299), closeTo(0.995, 0.01));
      expect(levelProgress(300), 0.0); // level 3 starts at 300
      expect(levelProgress(-5), 0); // clamped
    });

    test('level never drops below 1 for any input', () {
      for (var xp = -100; xp < 5000; xp += 7) {
        expect(levelFromXp(xp), greaterThanOrEqualTo(1));
      }
    });
  });

  group('nextLessonInCurriculum', () {
    final curriculum = [
      _chapter(
          'ch_a',
          [
            _lesson('a1', order: 0),
            _lesson('a2', order: 1),
          ],
          order: 0),
      _chapter(
          'ch_b',
          [
            _lesson('b1', order: 0),
            _lesson('b2', order: 1),
          ],
          order: 1),
    ];

    test('returns the first lesson when nothing is complete', () {
      expect(nextLessonInCurriculum(curriculum, {}), isNotNull);
      expect(nextLessonInCurriculum(curriculum, {})!.id, 'a1');
    });

    test('skips completed lessons in order', () {
      expect(
        nextLessonInCurriculum(curriculum, {'a1', 'a2'})!.id,
        'b1',
      );
      expect(
        nextLessonInCurriculum(curriculum, {'a1', 'a2', 'b1'})!.id,
        'b2',
      );
    });

    test('respects chapter order, not list order', () {
      final shuffled = [curriculum[1], curriculum[0]];
      expect(nextLessonInCurriculum(shuffled, {})!.id, 'a1');
    });

    test('returns null when everything is complete', () {
      expect(
        nextLessonInCurriculum(
          curriculum,
          {'a1', 'a2', 'b1', 'b2'},
        ),
        isNull,
      );
    });

    test('ignores unknown completed ids and tolerates empty chapters', () {
      expect(
        nextLessonInCurriculum([_chapter('empty', const [])], {'zzz'}),
        isNull,
      );
      expect(
        nextLessonInCurriculum(
          [
            _chapter('empty', const []),
            _chapter('c', [_lesson('c1')])
          ],
          {'zzz'},
        )!
            .id,
        'c1',
      );
    });
  });
}
