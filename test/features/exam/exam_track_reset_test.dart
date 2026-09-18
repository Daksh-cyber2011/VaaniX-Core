/// Exam track reset — per-track removal semantics (§21 course isolation).
///
/// The Profile Tray's "Reset Exam Track" clears four §21 per-track stores
/// for the ACTIVE track only. Two properties make that safe, and both are
/// pinned here because getting either wrong is silent data loss:
///
///   1. removal is scoped — a sibling exam track keeps every byte of its
///      profile, diagnostic mastery, PYQ evidence and mock history;
///   2. removal is a PRODUCTION api — each repository exposes
///      `remove(trackId)` alongside its test-only `reset()`, which wipes
///      the whole document. The UI must never reach for `reset()`.
///
/// The screen previously announced "reset successfully" while calling
/// nothing at all, so these tests also serve as the regression floor for
/// that fabrication: if `remove` stops removing, they fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/exam_learner_profile_repository.dart';
import 'package:vaanix_app/features/exam/data/exam_profile_repository.dart';
import 'package:vaanix_app/features/exam/data/pyq_mock/pyq_performance_repository.dart';
import 'package:vaanix_app/features/exam/domain/exam_learner_profile.dart';
import 'package:vaanix_app/features/exam/domain/exam_profile.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/mock_models.dart';
import 'package:vaanix_app/features/exam/domain/pyq_mock/pyq_models.dart';

const String activeTrack = 'cbse_10_hindi_a';
const String siblingTrack = 'cbse_10_science';

Future<LocalStorageService> freshPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return LocalStorageService(await SharedPreferences.getInstance());
}

ExamProfile _profile(String trackId, int minutes) => ExamProfile(
      trackId: trackId,
      dailyStudyMinutes: minutes,
      studyDaysPerWeek: 5,
      readinessDurationWeeks: 8,
    );

ExamLearnerProfile _learner(String trackId, String topicId) =>
    ExamLearnerProfile(
      trackId: trackId,
      topics: {
        topicId: TopicMastery(
          topicId: topicId,
          stage: TopicStage.learning,
          attemptCount: 4,
          correctCount: 2,
        ),
      },
      diagnosticCompletedAtIso: '2026-01-01T00:00:00.000Z',
      diagnosticOverallBand: 'learning',
    );

MockResult _mockResult(String trackId) => MockResult(
      paperId: 'p-$trackId',
      kind: MockKind.mini,
      trackId: trackId,
      sectionResults: const [],
      totalAttempted: 10,
      totalCorrect: 6,
      completedAtIso: '2026-01-02T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exam profile removal is scoped to one track', () async {
    final repo = ExamProfileRepository(await freshPrefs());
    expect(await repo.save(_profile(activeTrack, 30)), isTrue);
    expect(await repo.save(_profile(siblingTrack, 45)), isTrue);

    await repo.remove(activeTrack);

    expect(await repo.load(activeTrack), isNull);
    expect((await repo.load(siblingTrack))?.dailyStudyMinutes, 45);
  });

  test('learner profile removal is scoped to one track', () async {
    final repo = ExamLearnerProfileRepository(await freshPrefs());
    await repo.save(_learner(activeTrack, 'unit-1'));
    await repo.save(_learner(siblingTrack, 'unit-9'));

    await repo.remove(activeTrack);

    // `load` never returns null — absence is the empty profile, which is
    // exactly "diagnostic not taken" with no fabricated mastery.
    final cleared = await repo.load(activeTrack);
    expect(cleared.topics, isEmpty);
    expect(cleared.hasDiagnostic, isFalse);

    final sibling = await repo.load(siblingTrack);
    expect(sibling.topics.keys, ['unit-9']);
    expect(sibling.hasDiagnostic, isTrue);
  });

  test('PYQ evidence removal is scoped to one track', () async {
    final repo = PyqPerformanceRepository(await freshPrefs());
    await repo.mergeSession(trackId: activeTrack, outcomes: const [
      PyqTopicPerformance(topicId: 't1', attempted: 4, correct: 1),
    ]);
    await repo.mergeSession(trackId: siblingTrack, outcomes: const [
      PyqTopicPerformance(topicId: 't2', attempted: 3, correct: 3),
    ]);

    await repo.remove(activeTrack);

    expect(await repo.load(activeTrack), isEmpty);
    expect((await repo.load(siblingTrack))['t2']!.correct, 3);
  });

  test('mock history removal is scoped to one track', () async {
    final repo = MockResultRepository(await freshPrefs());
    await repo.record(_mockResult(activeTrack));
    await repo.record(_mockResult(siblingTrack));

    await repo.remove(activeTrack);

    expect(await repo.load(activeTrack), isEmpty);
    expect((await repo.load(siblingTrack)).length, 1);
  });

  test('removing an unknown track is a no-op, not a wipe', () async {
    final prefs = await freshPrefs();
    final profiles = ExamProfileRepository(prefs);
    expect(await profiles.save(_profile(activeTrack, 30)), isTrue);

    await profiles.remove('never_selected_track');

    expect((await profiles.load(activeTrack))?.dailyStudyMinutes, 30);
  });
}
