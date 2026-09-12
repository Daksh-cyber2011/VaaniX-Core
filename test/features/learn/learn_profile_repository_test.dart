/// Learn Profile Repository — M2 persistence tests.
///
/// Pins the storage contract: per-language namespaced keys
/// (`learn_profile_<iso>[_state]`), JSON round-trips, corruption safety
/// (missing / malformed / wrong-language values degrade to "unset",
/// never crash), and prefix-scoped cleanup.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';

Future<({LearnProfileRepository repo, ILocalStorageService storage})>
    _make({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  return (repo: LearnProfileRepository(storage), storage: storage);
}

LearnerProfile _profile(LearnLanguage language) =>
    LearnerProfile.initial(language).copyWith(
      goal: LearningGoal.conversation,
      desiredLevel: DesiredLevel.intermediate,
      pace: LearningPace.intense,
      dailyGoalMinutes: 20,
    );

void main() {
  group('profile persistence', () {
    test('unset language reads as null', () async {
      final m = await _make();
      expect(m.repo.getProfile(LearnLanguage.hindi), isNull);
      expect(m.repo.hasProfile(LearnLanguage.hindi), isFalse);
    });

    test('save + read round-trips every field', () async {
      final m = await _make();
      await m.repo.saveProfile(_profile(LearnLanguage.hindi));

      final restored = m.repo.getProfile(LearnLanguage.hindi);
      expect(restored, isNotNull);
      expect(restored!.language, LearnLanguage.hindi);
      expect(restored.goal, LearningGoal.conversation);
      expect(restored.desiredLevel, DesiredLevel.intermediate);
      expect(restored.pace, LearningPace.intense);
      expect(restored.dailyGoalMinutes, 20);
      expect(restored.selfReport, SelfReport.almostNothing);
      expect(m.repo.hasProfile(LearnLanguage.hindi), isTrue);
    });

    test('profiles are per-language and do not leak', () async {
      final m = await _make();
      await m.repo.saveProfile(_profile(LearnLanguage.hindi));

      expect(m.repo.getProfile(LearnLanguage.urdu), isNull);
      expect(m.repo.hasProfile(LearnLanguage.hindi), isTrue);
      expect(m.repo.hasProfile(LearnLanguage.urdu), isFalse);
    });

    test('malformed JSON degrades to unset, never throws', () async {
      final m = await _make(seed: {
        'learn_profile_hi': 'this is { not json',
      });
      expect(m.repo.getProfile(LearnLanguage.hindi), isNull);
      expect(m.repo.hasProfile(LearnLanguage.hindi), isFalse);
    });

    test('a JSON array or scalar degrades to unset', () async {
      final m = await _make(seed: {
        'learn_profile_hi': '[1,2,3]',
        'learn_profile_ur': '42',
      });
      expect(m.repo.getProfile(LearnLanguage.hindi), isNull);
      expect(m.repo.getProfile(LearnLanguage.urdu), isNull);
    });

    test('a profile stored under the WRONG language key is rejected', () async {
      // Simulate drift: a Bengali profile physically written under the
      // Hindi key (its own JSON says bengali).
      final payload = jsonEncode(
        LearnerProfile.initial(LearnLanguage.bengali).toJson(),
      );
      final m = await _make(seed: {'learn_profile_hi': payload});
      expect(m.repo.getProfile(LearnLanguage.hindi), isNull,
          reason: 'stored profile says bengali — a hindi read must '
              'reject it instead of cross-wiring languages');
    });

    test('clearProfile removes exactly that language', () async {
      final m = await _make();
      await m.repo.saveProfile(_profile(LearnLanguage.hindi));
      await m.repo.saveProfile(_profile(LearnLanguage.tamil));

      await m.repo.clearProfile(LearnLanguage.hindi);
      expect(m.repo.getProfile(LearnLanguage.hindi), isNull);
      expect(m.repo.getProfile(LearnLanguage.tamil), isNotNull);
    });
  });

  group('learning-state extras persistence', () {
    test('round-trips review queue and performance', () async {
      final m = await _make();
      final state = LearningState(
        languageCode: 'hi',
        reviewQueue: const [
          ReviewEntry(
              conceptId: 'hi_ls_1',
              reason: ReviewReason.recentlyWeak,
              priority: 0.8),
        ],
        recentPerformance: RecentPerformance(events: [
          PerformanceEvent(
              conceptId: 'hi_ls_1',
              correct: true,
              firstTry: true,
              at: DateTime.fromMillisecondsSinceEpoch(1700000000000)),
        ]),
      );

      await m.repo.saveLearningState(LearnLanguage.hindi, state);
      final restored = m.repo.getLearningState(LearnLanguage.hindi);
      expect(restored, isNotNull);
      expect(restored!.languageCode, 'hi');
      expect(restored.reviewQueue.single.conceptId, 'hi_ls_1');
      expect(restored.recentPerformance.events, hasLength(1));
    });

    test('unset / malformed state degrades to null', () async {
      final m = await _make(seed: {
        'learn_profile_hi_state': '{{nope',
      });
      expect(m.repo.getLearningState(LearnLanguage.hindi), isNull);
      expect(m.repo.getLearningState(LearnLanguage.urdu), isNull);
    });

    test('state stored under another language\u2019s key is rejected', () async {
      final m = await _make();
      // A state whose own languageCode says 'bn', saved under the HI key:
      await m.repo.saveLearningState(
        LearnLanguage.hindi,
        LearningState(languageCode: 'bn'),
      );
      expect(m.repo.getLearningState(LearnLanguage.hindi), isNull,
          reason: 'the language guard must reject cross-language state');
    });
  });

  group('clearAll', () {
    test('removes every learn_profile_* key and nothing else', () async {
      final m = await _make(seed: {
        'learn_language': 'hindi', // NOT namespaced — must survive
        'completed_lesson_ids': ['x'],
      });
      await m.repo.saveProfile(_profile(LearnLanguage.hindi));
      await m.repo.saveProfile(_profile(LearnLanguage.urdu));
      await m.repo.saveLearningState(
        LearnLanguage.hindi,
        LearningState(languageCode: 'hi'),
      );

      await m.repo.clearAll();

      expect(m.repo.hasProfile(LearnLanguage.hindi), isFalse);
      expect(m.repo.hasProfile(LearnLanguage.urdu), isFalse);
      expect(m.repo.getLearningState(LearnLanguage.hindi), isNull);
      // Untouched keys survive:
      expect(m.storage.getString('learn_language'), 'hindi');
      expect(m.storage.completedLessonIds, ['x']);
    });
  });
}
