import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('probe adaptive provider with seeded state', () async {
    SharedPreferences.setMockInitialValues(
        {'completed_lesson_ids': kAllLessonIds});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final learner = container.read(adaptiveNextActionProvider);
    print('PROBE CURR: ${container.read(curriculumProvider)}');
    print('PROBE COMPLETED: ${container.read(completedLessonIdsProvider)}');
    print('PROBE ACTION: ${learner.action} | ${learner.label}');
  });
}