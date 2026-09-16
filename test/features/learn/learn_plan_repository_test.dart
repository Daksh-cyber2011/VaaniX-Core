/// Learn Plan Repository — M4 persistence tests.
///
/// Pins the plan-cache storage contract: key `learn_profile_<iso>_plan`
/// inside the M2 namespace, JSON round-trips, corruption safety
/// (missing / malformed / wrong-language values degrade to "no cache",
/// never crash), non-catalogue languages are no-ops, freshness policy,
/// and the prefix-scoped reset covering the new key automatically.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

Future<({LearnPlanRepository repo, ILocalStorageService storage})> _make({
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  return (repo: LearnPlanRepository(storage), storage: storage);
}

LearningPlan _plan(
  String languageCode, {
  DateTime? createdAt,
}) {
  return LearningPlan(
    id: 'plan-test-1',
    languageCode: languageCode,
    source: PlanSource.ai,
    focusSummary: 'Test focus',
    activities: [
      LearningActivity(
        id: 'act-1',
        kind: ActivityKind.practice,
        title: 'Practice: Greetings',
        reason: 'Keep greetings fresh.',
        conceptId: 'hi_ls_1',
        lessonId: 'hi_ls_1',
        difficulty: Difficulty.beginner,
        estimatedMinutes: 5,
      ),
    ],
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('plan persistence', () {
    test('unset language reads as null', () async {
      final m = await _make();
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
      expect(m.repo.hasPlan(LearnLanguage.hindi), isFalse);
    });

    test('save + read round-trips the whole plan', () async {
      final m = await _make();
      await m.repo.savePlan(_plan('hi'));

      final restored = m.repo.getPlan(LearnLanguage.hindi);
      expect(restored, isNotNull);
      expect(restored!.languageCode, 'hi');
      expect(restored.source, PlanSource.ai);
      expect(restored.focusSummary, 'Test focus');
      expect(restored.activities, hasLength(1));
      expect(restored.activities.first.conceptId, 'hi_ls_1');
      expect(restored.activities.first.kind, ActivityKind.practice);
      expect(m.repo.hasPlan(LearnLanguage.hindi), isTrue);
    });

    test('plans are per-language and do not leak', () async {
      final m = await _make();
      await m.repo.savePlan(_plan('hi'));

      expect(m.repo.getPlan(LearnLanguage.bengali), isNull);
      expect(m.repo.hasPlan(LearnLanguage.bengali), isFalse);
    });

    test('malformed JSON degrades to unset, never throws', () async {
      final m = await _make(seed: {
        'learn_profile_hi_plan': '{not json at all',
      });
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });

    test('a JSON scalar degrades to unset', () async {
      final m = await _make(seed: {'learn_profile_hi_plan': '42'});
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });

    test('a plan stored under the WRONG language key is rejected', () async {
      final m = await _make();
      // Drift simulation: a Bengali plan physically written under the
      // Hindi plan key.
      await m.storage.setString(
        LearnPlanRepository.planKey(LearnLanguage.hindi),
        jsonEncode(_plan('bn').toJson()),
      );
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });

    test('clearPlan removes exactly that language\'s plan', () async {
      final m = await _make();
      await m.repo.savePlan(_plan('hi'));
      await m.repo.savePlan(_plan('ur'));

      await m.repo.clearPlan(LearnLanguage.hindi);

      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
      expect(m.repo.getPlan(LearnLanguage.urdu), isNotNull);
    });

    test('a non-catalogue language plan is a no-op (legacy Sanskrit)',
        () async {
      final m = await _make();
      await m.repo.savePlan(_plan('sa'));

      expect(m.storage.containsKey('learn_profile_sa_plan'), isFalse);
      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });

    test('the M2 prefix reset (clearAll) covers the plan key', () async {
      final m = await _make();
      await m.repo.savePlan(_plan('hi'));

      // The M2 profile repository owns the namespace-wide reset; the
      // M4 plan key inherits it by the prefix rule — no key list to sync.
      await LearnProfileRepository(m.storage).clearAll();

      expect(m.repo.getPlan(LearnLanguage.hindi), isNull);
    });
  });

  group('freshness policy', () {
    test('a brand-new plan is fresh', () {
      expect(LearnPlanRepository.isFresh(_plan('hi')), isTrue);
    });

    test('a week-old plan is stale', () {
      final old = _plan(
        'hi',
        createdAt: DateTime.now().subtract(
          LearnPlanRepository.kDefaultMaxAge + const Duration(hours: 1),
        ),
      );
      expect(LearnPlanRepository.isFresh(old), isFalse);
    });

    test('a future timestamp (clock skew) counts as fresh', () {
      final future = _plan(
        'hi',
        createdAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(LearnPlanRepository.isFresh(future), isTrue);
    });
  });
}
