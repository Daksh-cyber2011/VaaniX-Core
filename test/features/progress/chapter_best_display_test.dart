/// Chapter Best-Score Display Tests (Phase 2)
///
/// `chapterBestFractionProvider` used to omit chapters whose best fraction
/// was 0.0, so the Progress screen told a learner who had SAT the exam and
/// scored 0% "Exam not attempted". The provider now includes every chapter
/// with at least one attempt (even 0.0) and omits only truly-unattempted
/// chapters.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer(
      Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    // Settle the single-source asset loads before reading providers.
    await container.read(curriculumProvider.future);
    await container.read(quizBankProvider.future);
    return container;
  }

  test('a chapter attempted with 0% is reported as attempted (best 0.0)',
      () async {
    final container = await makeContainer(<String, Object>{
      'quiz_attempts_quiz_ch_alphabet_beginner': jsonEncode([
        {
          'quizId': 'quiz_ch_alphabet_beginner',
          'score': 0,
          'total': 6,
          'xpEarned': 0,
        },
      ]),
    });
    addTearDown(container.dispose);

    final best = container.read(chapterBestFractionProvider);

    expect(best.containsKey('ch_alphabet'), isTrue,
        reason: 'an attempted chapter must appear even with a 0% best');
    expect(best['ch_alphabet'], 0.0);
    expect(best.containsKey('ch_words'), isFalse,
        reason: 'chapters without ANY attempt stay absent (not attempted)');
  });

  test('a chapter with a real best keeps reporting the maximum', () async {
    final container = await makeContainer(<String, Object>{
      'quiz_attempts_quiz_ch_words_beginner': jsonEncode([
        {
          'quizId': 'quiz_ch_words_beginner',
          'score': 2,
          'total': 5,
          'xpEarned': 20,
        },
        {
          'quizId': 'quiz_ch_words_beginner',
          'score': 4,
          'total': 5,
          'xpEarned': 0,
        },
      ]),
    });
    addTearDown(container.dispose);

    final best = container.read(chapterBestFractionProvider);
    expect(best['ch_words'], closeTo(4 / 5, 0.0001));
  });
}
