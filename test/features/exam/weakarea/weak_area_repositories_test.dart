/// Exam Mode 2.0 — M8 Weak-Area Repository Tests (§12/§21/§41/§56)
///
/// Attempt-log persistence (batched writes, per-track isolation,
/// bounded history, corrupt-store degradation, wrong-id extraction)
/// and weak-area state persistence (schema round-trip, recovery
/// completion, revision merge, recheck outcome cap).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/weakarea/exam_attempt_log_repository.dart';
import 'package:vaanix_app/features/exam/data/weakarea/weak_area_repository.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/error_intelligence.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/remediation_engine.dart';
import 'package:vaanix_app/features/exam/domain/weakarea/revision_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalStorageService> freshPrefs(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  group('ExamAttemptLogRepository (§21 evidence, §12 persistence)', () {
    test('empty store → no evidence, no crash', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      expect(await repo.load('cbse_10_sanskrit'), isEmpty);
      expect(await repo.loadAll(), isEmpty);
    });

    test('recordSession batches and reloads (one write per session)', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      await repo.recordSession(
        trackId: 'cbse_10_sanskrit',
        attempts: [
          ErrorEvidence(
            questionId: 'prac_a_sec',
            topicId: 'cbse_10_sanskrit_a',
            kind: 'mcq',
            verdict: 'incorrect',
            retries: 1,
            atIso: '2026-09-12T10:00:00.000',
          ),
          ErrorEvidence(
            questionId: 'prac_a_typed',
            topicId: 'cbse_10_sanskrit_a',
            kind: 'typed',
            verdict: 'correct',
            retries: 0,
            atIso: '2026-09-12T10:02:00.000',
          ),
        ],
      );
      final loaded = await repo.load('cbse_10_sanskrit');
      expect(loaded, hasLength(2));
      expect(loaded.first.verdict, 'incorrect');
      expect(loaded.last.kind, 'typed');
    });

    test('per-track isolation (§course isolation)', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      await repo.recordSession(
        trackId: 'cbse_10_sanskrit',
        attempts: [
          ErrorEvidence(
              questionId: 'q1',
              topicId: 't1',
              kind: 'mcq',
              verdict: 'incorrect',
              retries: 0,
              atIso: ''),
        ],
      );
      await repo.recordSession(
        trackId: 'cbse_10_hindi_a',
        attempts: [
          ErrorEvidence(
              questionId: 'q2',
              topicId: 't2',
              kind: 'mcq',
              verdict: 'correct',
              retries: 0,
              atIso: ''),
        ],
      );
      final sanskrit = await repo.load('cbse_10_sanskrit');
      final hindi = await repo.load('cbse_10_hindi_a');
      expect(sanskrit.map((e) => e.questionId), ['q1']);
      expect(hindi.map((e) => e.questionId), ['q2']);
    });

    test('§56 bound: log never exceeds maxEntries', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      final burst = [
        for (var i = 0; i < ExamAttemptLogRepository.maxEntries + 40; i++)
          ErrorEvidence(
              questionId: 'q$i',
              topicId: 't1',
              kind: 'mcq',
              verdict: 'incorrect',
              retries: 0,
              atIso: '2026-09-12T10:00:00.000'),
      ];
      await repo.recordSession(trackId: 'x', attempts: burst);
      final loaded = await repo.load('x');
      expect(loaded.length, ExamAttemptLogRepository.maxEntries);
      // Newest retained: the first 40 were trimmed.
      expect(loaded.first.questionId, 'q40');
      expect(loaded.last.questionId,
          'q${ExamAttemptLogRepository.maxEntries + 39}');
    });

    test('defensive: empty ids and empty batches are never stored', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      await repo.recordSession(trackId: 'x', attempts: [
        const ErrorEvidence(
            questionId: '', topicId: '', kind: 'mcq', verdict: '', retries: 0, atIso: ''),
      ]);
      expect(await repo.load('x'), isEmpty);
      await repo.recordSession(trackId: 'x', attempts: const []);
      expect(await repo.load('x'), isEmpty);
    });

    test('corrupt store degrades to empty — never crashes (§41)', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs({
        ExamAttemptLogRepository.storageKey: '{{{not json',
      }));
      expect(await repo.loadAll(), isEmpty);
    });

    test('corrupt single track entry is skipped, rest survive (§41)',
        () async {
      final good = ErrorEvidence(
              questionId: 'q1',
              topicId: 't1',
              kind: 'mcq',
              verdict: 'incorrect',
              retries: 0,
              atIso: '')
          .toJson();
      final corruptJson = jsonEncode({
        'version': 1,
        'entries': {
          'good': [good],
          'bad': 'not-a-list',
        },
      });
      final repo = ExamAttemptLogRepository(
          await freshPrefs({ExamAttemptLogRepository.storageKey: corruptJson}));
      final all = await repo.loadAll();
      expect(all['good'], hasLength(1));
      expect(all.containsKey('bad'), isFalse);
    });

    test('wrongQuestionIdsByTopic extracts only wrong verdicts', () {
      final map = ExamAttemptLogRepository.wrongQuestionIdsByTopic([
        ErrorEvidence(
            questionId: 'w1',
            topicId: 't1',
            kind: 'mcq',
            verdict: 'incorrect',
            retries: 0,
            atIso: ''),
        ErrorEvidence(
            questionId: 'w2',
            topicId: 't1',
            kind: 'mcq',
            verdict: 'revealed',
            retries: 0,
            atIso: ''),
        ErrorEvidence(
            questionId: 'c1',
            topicId: 't1',
            kind: 'mcq',
            verdict: 'correct',
            retries: 0,
            atIso: ''),
        ErrorEvidence(
            questionId: 'p1',
            topicId: 't2',
            kind: 'typed',
            verdict: 'partiallyCorrect',
            retries: 0,
            atIso: ''),
      ]);
      expect(map['t1'], {'w1', 'w2'});
      expect(map['t2'], {'p1'});
    });

    test('reset clears the log (test hygiene)', () async {
      final repo = ExamAttemptLogRepository(await freshPrefs());
      await repo.recordSession(
        trackId: 'x',
        attempts: [
          ErrorEvidence(
              questionId: 'q1',
              topicId: 't1',
              kind: 'mcq',
              verdict: 'incorrect',
              retries: 0,
              atIso: ''),
        ],
      );
      await repo.reset();
      expect(await repo.load('x'), isEmpty);
    });
  });

  group('WeakAreaRepository (§12/§22/§23/§56)', () {
    test('empty store → empty state, never a crash', () async {
      final repo = WeakAreaRepository(await freshPrefs());
      final state = await repo.load('cbse_10_sanskrit');
      expect(state.trackId, 'cbse_10_sanskrit');
      expect(state.revision, isEmpty);
      expect(state.recheckOutcomes, isEmpty);
      expect(state.recoveryDayCount, 0);
    });

    test('withRecoveryCompleted increments history (§22 frequency evidence)',
        () async {
      final repo = WeakAreaRepository(await freshPrefs());
      var state = await repo.load('x');
      final t = DateTime(2026, 9, 12);
      state = state.withRecoveryCompleted(t);
      state = state.withRecoveryCompleted(t.add(const Duration(days: 4)));
      await repo.save(state);
      final back = await repo.load('x');
      expect(back.recoveryDayCount, 2);
      expect(back.lastRecoveryDayIso,
          t.add(const Duration(days: 4)).toIso8601String());
    });

    test('revision ladder state survives a round-trip (§23 memory)', () async {
      final repo = WeakAreaRepository(await freshPrefs());
      final item = RevisionEngine.expand(
        RevisionItem(
            topicId: 't1', intervalIndex: 0, lastReviewedIso: '', dueIso: ''),
        DateTime(2026, 9, 12),
      );
      var state = await repo.load('x');
      state = state.withRevision({'t1': item});
      await repo.save(state);

      final back = await repo.load('x');
      expect(back.revision['t1']!.intervalIndex, 1);
      expect(back.revision['t1']!.intervalDays, 2);
    });

    test('recheck outcome log is bounded at 100 (§56)', () async {
      final repo = WeakAreaRepository(await freshPrefs());
      var state = await repo.load('x');
      for (var i = 0; i < 130; i++) {
        state = state.withRecheckOutcome(RecheckOutcomeRecord(
          topicId: 't$i % 7',
          outcome: RemediationOutcome.recovered,
          atIso: '2026-09-01T10:00:00.000',
        ));
      }
      expect(state.recheckOutcomes.length, 100);
      // Newest kept, oldest trimmed.
      expect(
          state.recheckOutcomes.first.topicId, 't${130 - 100} % 7');
      await repo.save(state);
      expect((await repo.load('x')).recheckOutcomes.length, 100);
    });

    test('schema version round-trips (§57 migration safety)', () async {
      final repo = WeakAreaRepository(await freshPrefs());
      var state = await repo.load('x');
      state = state.withRevision({
        't1': RevisionItem(
            topicId: 't1', intervalIndex: 2, lastReviewedIso: '', dueIso: ''),
      });
      await repo.save(state);
      final raw = (await SharedPreferences.getInstance())
          .getString(WeakAreaRepository.storageKey)!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['version'], 1);
      final stateJson =
          (json['states'] as Map<String, dynamic>)['x'] as Map<String, dynamic>;
      expect(stateJson['schemaVersion'], WeakAreaState.currentSchemaVersion);
    });

    test('corrupt store degrades to empty state (§41)', () async {
      final repo = WeakAreaRepository(
          await freshPrefs({WeakAreaRepository.storageKey: 'null-ish garbage'}));
      expect((await repo.load('x')).revision, isEmpty);
    });

    test('corrupt single revision entry skipped, rest survive (§41)',
        () async {
      final good = RevisionItem(
              topicId: 't1',
              intervalIndex: 3,
              lastReviewedIso: '2026-09-01T10:00:00.000',
              dueIso: '2026-09-08T10:00:00.000')
          .toJson();
      final corruptState = jsonEncode({
        'version': 1,
        'states': {
          'x': {
            'schemaVersion': 1,
            'trackId': 'x',
            'revision': {'good': good, 'bad': 42},
            'recheckOutcomes': ['not-a-map'],
          },
        },
      });
      final repo = WeakAreaRepository(
          await freshPrefs({WeakAreaRepository.storageKey: corruptState}));
      final state = await repo.load('x');
      expect(state.revision['good']!.intervalIndex, 3);
      expect(state.revision.containsKey('bad'), isFalse);
      expect(state.recheckOutcomes, isEmpty);
    });

    test('reset clears per-track state (test hygiene)', () async {
      final repo = WeakAreaRepository(await freshPrefs());
      var state = await repo.load('x');
      state = state.withRecoveryCompleted(DateTime.now());
      await repo.save(state);
      await repo.reset();
      expect((await repo.load('x')).recoveryDayCount, 0);
    });
  });
}
