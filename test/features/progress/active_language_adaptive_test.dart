/// M1 (G7) — Adaptive engine now follows the ACTIVE Learn language.
///
/// End-to-end provider-chain proof: persisted language selection
/// (`learn_language = hindi`) flows through the REAL repositories into
/// [adaptiveNextActionProvider], which must now target Hindi lessons:
/// - fresh Hindi learner   → startJourney at the first `hi_` lesson;
/// - completed-but-unmastered Hindi lesson → practiceWeakTopic on it;
/// - EVERY Hindi lesson completed → allDone (NOT takeChapterExam — Hindi
///   chapters ship no exams; the pre-M1 engine would have demanded one).
///
/// Runs the real async chain (plain test zone) against the real hi.json
/// asset — same approach as adaptive_providers_test.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/domain/adaptive.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';

List<String> _hindiLessonIds() {
  final file = File('assets/curriculum/learn/hi.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final chapters = json['chapters'] as List<dynamic>;
  return [
    for (final ch in chapters)
      for (final lesson in (ch as Map<String, dynamic>)['lessons']
          as List<dynamic>)
        (lesson as Map<String, dynamic>)['id'] as String,
  ];
}

Future<ProviderContainer> _container(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Settle the whole chain before any adaptive read.
  await container.read(quizBankProvider.future);
  await container.read(activeCurriculumProvider.future);
  return container;
}

final allLessons = _hindiLessonIds();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  assert(allLessons.isNotEmpty, 'hi.json must ship real lessons');

  test('language selection alone moves the CTA to the Hindi curriculum',
      () async {
    final container = await _container({
      AppConstants.keyLearnLanguage: 'hindi',
    });
    addTearDown(container.dispose);

    final action = container.read(adaptiveNextActionProvider);
    expect(action.action, AdaptiveAction.startJourney);
    expect(action.lessonId, allLessons.first);
    expect(action.lessonId, startsWith('hi_'));
  });

  test('completed unmastered Hindi lessons surface as weak-topic practice',
      () async {
    final container = await _container({
      AppConstants.keyLearnLanguage: 'hindi',
      AppConstants.keyCompletedLessonIds: allLessons.take(2).toList(),
    });
    addTearDown(container.dispose);

    final action = container.read(adaptiveNextActionProvider);
    expect(action.action, AdaptiveAction.practiceWeakTopic);
    expect(action.lessonId, allLessons.first);
    expect(action.label, contains('Practice'));
  });

  test('full Hindi journey completion yields allDone — never a phantom exam',
      () async {
    final container = await _container({
      AppConstants.keyLearnLanguage: 'hindi',
      AppConstants.keyCompletedLessonIds: allLessons,
    });
    addTearDown(container.dispose);

    final action = container.read(adaptiveNextActionProvider);
    expect(action.action, AdaptiveAction.allDone,
        reason: 'Hindi chapters have no exams; takeChapterExam would be a '
            'phantom recommendation');
    expect(action.chapterId, isNull);
  });

  test('Sanskrit fallback stays intact when NO language is selected',
      () async {
    final container = await _container({});
    addTearDown(container.dispose);

    final action = container.read(adaptiveNextActionProvider);
    // Legacy Sanskrit curriculum: first lesson + still exam-gated.
    expect(action.lessonId, 'ls_alphabet_vowels');
    expect(action.action, AdaptiveAction.startJourney);
  });
}
