/// Learn Mode 2.0 — Learning State derivation tests (M1 spine).
///
/// Pins the honest old→new evidence mapping (completed/mastered lessons →
/// concept mastery stages), the bounded review queue and recent
/// performance window, and JSON round-trip integrity (M2 storage is a
/// drop-in). Pure Dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'ch_1',
          title: 'Chapter 1',
          lessons: [
            Lesson(id: 'hi_ls_1', title: 'one', chapterId: 'ch_1'),
            Lesson(id: 'hi_ls_2', title: 'two', chapterId: 'ch_1'),
            Lesson(id: 'hi_ls_3', title: 'three', chapterId: 'ch_1'),
          ],
        ),
      ],
    );

ProgressSnapshot _snapshot({
  Set<String> completed = const {},
  Map<String, List<String>> mastered = const {},
  Map<String, int> counts = const {},
}) {
  return ProgressSnapshot(
    completedLessonIds: completed,
    masteredExerciseIdsByLesson: mastered,
    exerciseCountByLesson: counts,
  );
}

void main() {
  group('deriveLearningState — evidence-only stage mapping', () {
    test('lesson completed with no exercises → introduced', () {
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: _graph(),
        snapshot: _snapshot(
          completed: {'hi_ls_1'},
          counts: {'hi_ls_1': 0},
        ),
      );
      expect(state.stageOf('hi_ls_1'), MasteryStage.introduced);
      expect(state.stageOf('hi_ls_2'), isNull); // not started = no record
      expect(state.conceptMasteries, hasLength(1));
    });

    test('lesson completed with SOME exercises mastered → practiced', () {
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: _graph(),
        snapshot: _snapshot(
          completed: {'hi_ls_1'},
          mastered: {
            'hi_ls_1': ['ex_1'],
          },
          counts: {'hi_ls_1': 4},
        ),
      );
      expect(state.stageOf('hi_ls_1'), MasteryStage.practiced);
      expect(state.conceptMasteries['hi_ls_1']!.strength, closeTo(0.25, 1e-9));
    });

    test('lesson completed with ALL exercises mastered → understood', () {
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: _graph(),
        snapshot: _snapshot(
          completed: {'hi_ls_1'},
          mastered: {
            'hi_ls_1': ['ex_1', 'ex_2', 'ex_3', 'ex_4'],
          },
          counts: {'hi_ls_1': 4},
        ),
      );
      expect(state.stageOf('hi_ls_1'), MasteryStage.understood);
      expect(state.conceptMasteries['hi_ls_1']!.strength, closeTo(1.0, 1e-9));
    });

    test('uncompleted lessons NEVER get fabricated records', () {
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: _graph(),
        snapshot: _snapshot(counts: {'hi_ls_2': 5}),
      );
      expect(state.conceptMasteries, isEmpty);
      expect(state.conceptIdsAtLeast(MasteryStage.introduced), isEmpty);
    });

    test('readyToLearn returns unlocked, unstarted concepts only', () {
      final graph = _graph();
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: graph,
        snapshot: _snapshot(
          completed: {'hi_ls_1'},
          mastered: {
            'hi_ls_1': ['ex_1'],
          },
          counts: {'hi_ls_1': 2},
        ),
      );
      final ready = state.readyToLearn(graph);
      // ls_1 started, ls_2 unlocked (prereq practiced), ls_3 locked
      // (prereq ls_2 has no mastery at all).
      expect(ready.map((c) => c.id), ['hi_ls_2']);
    });
  });

  group('ReviewEntry queue + RecentPerformance bounds', () {
    test('queue is sorted by priority descending and round-trips', () {
      final entries = [
        const ReviewEntry(
            conceptId: 'a', reason: ReviewReason.recentlyWeak, priority: 0.9),
        const ReviewEntry(
            conceptId: 'b', reason: ReviewReason.maintenance, priority: 0.2),
        const ReviewEntry(
            conceptId: 'c', reason: ReviewReason.agingStrong, priority: 0.5),
      ];
      final state = deriveLearningState(
        languageCode: 'hi',
        graph: _graph(),
        snapshot: _snapshot(),
        reviewQueue: entries,
      );
      expect(
          state.reviewQueue.map((e) => e.conceptId).toList(), ['a', 'c', 'b']);

      final restored = LearningState.fromJson(state.toJson());
      expect(restored.reviewQueue.map((e) => e.conceptId).toList(),
          ['a', 'c', 'b']);
    });

    test('recent performance window is capped and accuracy is honest', () {
      var perf = const RecentPerformance();
      for (var i = 0; i < RecentPerformance.kMaxEvents + 5; i++) {
        perf = perf.add(PerformanceEvent(
          conceptId: 'hi_ls_1',
          correct: i % 2 == 0,
          firstTry: i % 2 == 0,
          at: DateTime.now().add(Duration(minutes: i)),
        ));
      }
      expect(perf.events.length, RecentPerformance.kMaxEvents);
      expect(perf.accuracy, isNotNull);
      expect(perf.accuracy! > 0, isTrue);

      const empty = RecentPerformance();
      expect(empty.accuracy, isNull); // never fabricate 0% for no history
      expect(empty.firstTryAccuracy, isNull);
    });
  });

  group('LearningState JSON round-trip (M2 storage readiness)', () {
    test('masteries + queue + performance survive a full round-trip', () {
      final state = deriveLearningState(
        languageCode: 'ur',
        graph: ConceptGraph.forCurriculum(
          languageCode: 'ur',
          chapters: const [
            Chapter(
              id: 'ch_1',
              title: 'C1',
              lessons: [Lesson(id: 'ur_ls_1', title: 'one', chapterId: 'ch_1')],
            ),
          ],
        ),
        snapshot: _snapshot(
          completed: {'ur_ls_1'},
          mastered: {
            'ur_ls_1': ['ex_1', 'ex_2'],
          },
          counts: {'ur_ls_1': 4},
        ),
        reviewQueue: const [
          ReviewEntry(
              conceptId: 'ur_ls_1',
              reason: ReviewReason.recentlyWeak,
              priority: 0.7),
        ],
        recentPerformance: RecentPerformance(events: [
          PerformanceEvent(
              conceptId: 'ur_ls_1',
              correct: true,
              firstTry: true,
              at: DateTime.fromMillisecondsSinceEpoch(1700000000000)),
        ]),
      );

      final restored = LearningState.fromJson(state.toJson());
      expect(restored.languageCode, 'ur');
      expect(restored.stageOf('ur_ls_1'), MasteryStage.practiced);
      expect(restored.reviewQueue.single.conceptId, 'ur_ls_1');
      expect(restored.recentPerformance.events.single.correct, isTrue);
    });
  });
}
