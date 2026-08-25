import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';

const List<String> kAllLessonIds = [
  'ls_alphabet_vowels',
  'ls_alphabet_consonants',
  'ls_alphabet_barakhadi',
  'ls_alphabet_conjuncts',
  'ls_words_greetings',
  'ls_words_family',
  'ls_words_numbers',
  'ls_sentences_intro',
  'ls_sentences_questions',
  'ls_sentences_translation',
  'ls_grammar_nouns_cases',
  'ls_grammar_pronouns',
  'ls_grammar_verbs',
];

const List<String> kAllQuizIds = [
  'quiz_ch_alphabet_beginner',
  'quiz_ch_alphabet_intermediate',
  'quiz_ch_words_beginner',
  'quiz_ch_words_intermediate',
  'quiz_ch_sentences_intermediate',
  'quiz_ch_sentences_advanced',
  'quiz_ch_grammar_beginner',
  'quiz_ch_grammar_intermediate',
];

Map<String, Object> _passingAttempts() {
  final prefs = <String, Object>{};
  for (final id in kAllQuizIds) {
    prefs['quiz_attempts_$id'] = jsonEncode([
      {'quizId': id, 'score': 5, 'total': 5, 'xpEarned': 50},
    ]);
  }
  return prefs;
}

Future<void> _pumpHome(WidgetTester tester, Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // The Supabase SDK throws NotInitializedError in tests (its
        // initialize() is only called by app bootstrap). Route the auth
        // chain through the offline repo so Home renders normally.
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );

  // The curriculum asset is read through the platform channel, which the
  // fake-async test zone does not deliver reliably. Run the real event loop
  // briefly so the in-flight load completes and the adaptive provider
  // recomputes against the REAL curriculum.
  await tester.runAsync(() async {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  // Render the settled state.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _drainVan(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Fonts are not bundled in the test asset tree; the test framework must
  // not attempt a runtime network fetch for them either.
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('fresh learner sees the Start Learning action', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(tester, <String, Object>{});
    expect(find.text('Start Learning'), findsWidgets,
        reason: 'primary CTA and/or card must recommend starting');
    expect(find.textContaining('Namaste'), findsWidgets,
        reason: 'VAN must welcome the fresh learner');
    await _drainVan(tester);
  });

  testWidgets('syllabus complete but exams pending -> Exam time',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(
      tester,
      {AppConstants.keyCompletedLessonIds: kAllLessonIds},
    );
    expect(find.text('Exam time!'), findsOneWidget,
        reason: 'finished syllabus must recommend the chapter exam');
    await _drainVan(tester);
  });

  testWidgets('syllabus and exams complete -> Revise with VAN',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpHome(
      tester,
      {
        AppConstants.keyCompletedLessonIds: kAllLessonIds,
        ..._passingAttempts(),
      },
    );
    expect(find.text('Revise with VAN'), findsWidgets,
        reason: 'complete journey must recommend revision with VAN');
    expect(find.text('Syllabus complete!'), findsOneWidget);
    await _drainVan(tester);
  });
}