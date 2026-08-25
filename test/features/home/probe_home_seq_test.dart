import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/home/presentation/screens/home_screen.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/progress/presentation/providers/adaptive_providers.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

const List<String> kAllLessonIds = [
  'ls_alphabet_vowels', 'ls_alphabet_consonants', 'ls_alphabet_barakhadi',
  'ls_alphabet_conjuncts', 'ls_words_greetings', 'ls_words_family',
  'ls_words_numbers', 'ls_sentences_intro', 'ls_sentences_questions',
  'ls_sentences_translation', 'ls_grammar_nouns_cases', 'ls_grammar_pronouns',
  'ls_grammar_verbs',
];

Future<void> _pumpHome(WidgetTester tester, Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await rootBundle.loadString('assets/curriculum/v1.json');
  });

  testWidgets('first test - fresh', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pumpHome(tester, <String, Object>{});
    final ctx = tester.element(find.byType(HomeScreen));
    final c = ProviderScope.containerOf(ctx);
    print('T1 CURR: ${c.read(curriculumProvider)}');
    print('T1 ACTION: ${c.read(adaptiveNextActionProvider).action}');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('second test - exam due', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pumpHome(
      tester,
      {AppConstants.keyCompletedLessonIds: kAllLessonIds},
    );
    final ctx = tester.element(find.byType(HomeScreen));
    final c = ProviderScope.containerOf(ctx);
    print('T2 CURR: ${c.read(curriculumProvider)}');
    print('T2 COMPLETED: ${c.read(completedLessonIdsProvider).length}');
    print('T2 ACTION: ${c.read(adaptiveNextActionProvider).action}');
    print('T2 LABEL: ${c.read(adaptiveNextActionProvider).label}');
    await tester.pump(const Duration(seconds: 8));
  });
}