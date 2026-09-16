/// Exam Mode 2.0 — M9 Repository Tests (§12/§41/§56)
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/pyq_mock/pyq_performance_repository.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalStorageService> freshPrefs(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  group('PyqPerformanceRepository (§21 pyqPerformance)', () {
    test('empty store → empty performance', () async {
      final repo = PyqPerformanceRepository(await freshPrefs());
      expect(await repo.load('x'), isEmpty);
      expect(await repo.loadAll(), isEmpty);
    });

    test('mergeSession accumulates per-topic evidence', () async {
      final repo = PyqPerformanceRepository(await freshPrefs());
      await repo.mergeSession(trackId: 'x', outcomes: const [
        PyqTopicPerformance(topicId: 't1', attempted: 2, correct: 1),
        PyqTopicPerformance(topicId: 't2', attempted: 3, correct: 3),
      ]);
      await repo.mergeSession(trackId: 'x', outcomes: const [
        PyqTopicPerformance(topicId: 't1', attempted: 2, correct: 0),
      ]);
      final loaded = await repo.load('x');
      expect(loaded['t1']!.attempted, 4);
      expect(loaded['t1']!.correct, 1);
      expect(loaded['t2']!.correct, 3);
    });

    test('per-track isolation', () async {
      final repo = PyqPerformanceRepository(await freshPrefs());
      await repo.mergeSession(trackId: 'a', outcomes: const [
        PyqTopicPerformance(topicId: 't1', attempted: 2, correct: 2),
      ]);
      await repo.mergeSession(trackId: 'b', outcomes: const [
        PyqTopicPerformance(topicId: 't1', attempted: 5, correct: 0),
      ]);
      expect((await repo.load('a'))['t1']!.correct, 2);
      expect((await repo.load('b'))['t1']!.correct, 0);
    });

    test('§56 bound: keeps the topics with the most evidence', () async {
      final repo = PyqPerformanceRepository(await freshPrefs());
      await repo.mergeSession(trackId: 'x', outcomes: [
        for (var i = 0; i < PyqPerformanceRepository.maxTopics + 10; i++)
          PyqTopicPerformance(
              topicId: 't$i', attempted: i == 0 ? 100 : 1, correct: 0),
      ]);
      final loaded = await repo.load('x');
      expect(loaded.length, PyqPerformanceRepository.maxTopics);
      // The high-evidence topic survives the trim.
      expect(loaded['t0']!.attempted, 100);
      expect(loaded.containsKey('t${PyqPerformanceRepository.maxTopics + 9}'),
          isFalse);
    });

    test('empty outcomes are a no-op; corrupt store degrades (§41)', () async {
      final repo = PyqPerformanceRepository(await freshPrefs());
      await repo.mergeSession(trackId: 'x', outcomes: const []);
      expect(await repo.load('x'), isEmpty);
      final corrupt = PyqPerformanceRepository(
          await freshPrefs({PyqPerformanceRepository.storageKey: 'not-json'}));
      expect(await corrupt.loadAll(), isEmpty);
    });
  });

  group('MockResultRepository (§21 mockPerformance, §41 critical)', () {
    MockResult resultOf(String track, int attempted, int correct,
            {String sectionId = 's1'}) =>
        MockResult(
          paperId: 'p-$track-$attempted',
          kind: MockKind.mini,
          trackId: track,
          sectionResults: [
            MockSectionResult(
                sectionId: sectionId,
                title: 'S',
                attempted: attempted,
                correct: correct),
          ],
          totalAttempted: attempted,
          totalCorrect: correct,
          completedAtIso: '2026-09-12T10:00:00',
        );

    test('record + load round-trip', () async {
      final repo = MockResultRepository(await freshPrefs());
      await repo.record(resultOf('x', 5, 2));
      final loaded = await repo.load('x');
      expect(loaded, hasLength(1));
      expect(loaded.first.totalCorrect, 2);
      expect(loaded.first.sectionResults.first.title, 'S');
    });

    test('zero-attempt results are never stored (§41 honesty)', () async {
      final repo = MockResultRepository(await freshPrefs());
      await repo.record(resultOf('x', 0, 0));
      expect(await repo.load('x'), isEmpty);
    });

    test('§56 bound: newest kept', () async {
      final repo = MockResultRepository(await freshPrefs());
      for (var i = 0; i < MockResultRepository.maxResults + 10; i++) {
        await repo.record(resultOf('x', i + 1, 1));
      }
      final loaded = await repo.load('x');
      expect(loaded.length, MockResultRepository.maxResults);
      expect(loaded.first.paperId, 'p-x-11');
      expect(
          loaded.last.paperId, 'p-x-${MockResultRepository.maxResults + 10}');
    });

    test('per-track isolation + corrupt degradation (§41)', () async {
      final repo = MockResultRepository(await freshPrefs());
      await repo.record(resultOf('a', 3, 3));
      expect(await repo.load('b'), isEmpty);
      final corrupt = MockResultRepository(
          await freshPrefs({MockResultRepository.storageKey: 'garbage'}));
      expect(await corrupt.loadAll(), isEmpty);
    });

    test('JSON carries schema version (§57)', () async {
      final repo = MockResultRepository(await freshPrefs());
      await repo.record(resultOf('x', 2, 1));
      final raw = (await SharedPreferences.getInstance())
          .getString(MockResultRepository.storageKey)!;
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      expect(doc['version'], 1);
    });
  });
}
