/// Learn Profile Repository — M3 diagnostic-slot persistence tests.
///
/// Pins the `learn_profile_<iso>_diagnostic` contract: JSON round-trip,
/// per-language isolation, corruption safety (malformed / wrong-language
/// values degrade to "not placed", never crash), retake overwrite, and
/// prefix-scoped cleanup coverage.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/diagnostic.dart';

Future<({LearnProfileRepository repo, ILocalStorageService storage})>
    _make({Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  return (repo: LearnProfileRepository(storage), storage: storage);
}

DiagnosticResult _result(LearnLanguage language, {int level = 2}) {
  return DiagnosticResult(
    language: language,
    overallLevel: level,
    dimensionScores: {
      DiagnosticDimension.vocabulary: const DimensionScore(
        dimension: DiagnosticDimension.vocabulary,
        score: 0.5,
        confidence: 0.45,
        asked: 2,
        correct: 1,
      ),
      DiagnosticDimension.script: const DimensionScore(
        dimension: DiagnosticDimension.script,
        score: 1.0,
        confidence: 0.45,
        asked: 2,
        correct: 2,
      ),
    },
    confidence: 0.45,
    duration: const Duration(minutes: 4, seconds: 12),
    completedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
}

void main() {
  group('diagnostic persistence', () {
    test('unset language reads as null (not placed yet)', () async {
      final m = await _make();
      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNull);
    });

    test('save + read round-trips the structured result', () async {
      final m = await _make();
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi));

      final restored = m.repo.getDiagnostic(LearnLanguage.hindi);
      expect(restored, isNotNull);
      expect(restored!.language, LearnLanguage.hindi);
      expect(restored.overallLevel, 2);
      expect(restored.levelLabel, 'Elementary');
      expect(restored.dimensionScores, hasLength(2));
      expect(restored.dimensionScores[DiagnosticDimension.script]!.correct, 2);
      expect(restored.confidence, moreOrLessEquals(0.45, epsilon: 1e-9));
      expect(restored.duration, const Duration(minutes: 4, seconds: 12));
      expect(
        restored.completedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('diagnostics are per-language and do not leak', () async {
      final m = await _make();
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi));

      expect(m.repo.getDiagnostic(LearnLanguage.urdu), isNull);
      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNotNull);
    });

    test('malformed JSON degrades to unset, never throws', () async {
      final m = await _make(seed: {
        'learn_profile_hi_diagnostic': '{not json at all',
      });
      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNull);
    });

    test('a result stored under the WRONG language key is rejected',
        () async {
      final m = await _make();
      // A Bengali result physically written under the Hindi key.
      final payload =
          jsonEncode(_result(LearnLanguage.bengali).toJson());
      await m.storage.setString(
        LearnProfileRepository.diagnosticKey(LearnLanguage.hindi),
        payload,
      );
      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNull,
          reason: 'the language guard must reject cross-language drift');
    });

    test('a retake overwrites the previous result', () async {
      final m = await _make();
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi, level: 0));
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi, level: 3));

      final restored = m.repo.getDiagnostic(LearnLanguage.hindi);
      expect(restored!.overallLevel, 3);
    });

    test('clearDiagnostic removes exactly that language', () async {
      final m = await _make();
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi));
      await m.repo.saveDiagnostic(_result(LearnLanguage.tamil));

      await m.repo.clearDiagnostic(LearnLanguage.hindi);
      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNull);
      expect(m.repo.getDiagnostic(LearnLanguage.tamil), isNotNull);
    });

    test('the key follows the learn_profile_<iso>_diagnostic contract',
        () {
      expect(
        LearnProfileRepository.diagnosticKey(LearnLanguage.hindi),
        'learn_profile_hi_diagnostic',
      );
      expect(
        LearnProfileRepository.diagnosticKey(LearnLanguage.urdu),
        'learn_profile_ur_diagnostic',
      );
    });

    test('clearAll covers the diagnostic slot too', () async {
      final m = await _make(seed: {
        'learn_language': 'hindi', // NOT namespaced — must survive
      });
      await m.repo.saveDiagnostic(_result(LearnLanguage.hindi));
      await m.repo.saveDiagnostic(_result(LearnLanguage.urdu));

      await m.repo.clearAll();

      expect(m.repo.getDiagnostic(LearnLanguage.hindi), isNull);
      expect(m.repo.getDiagnostic(LearnLanguage.urdu), isNull);
      expect(m.storage.getString('learn_language'), 'hindi');
    });
  });
}
