import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/personalized_course_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('personalized course round-trips through local storage', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repository = PersonalizedCourseRepository(
      ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      ).read(localStorageServiceProvider),
    );
    addTearDown(prefs.clear);

    final course = PersonalizedCourse(
      id: 'course_hi_1',
      languageCode: 'hi',
      source: PlanSource.ai,
      generatedAt: DateTime(2026, 9, 26),
      contextKey: 'ctx-1',
      curriculumRevision: '2',
      units: [
        PersonalizedUnit(
          id: 'unit_hi_1',
          title: 'Foundations',
          objective: 'Build a base',
          order: 1,
          lessons: [
            PersonalizedLesson(
              id: 'lesson_hi_hello',
              conceptId: 'hi_hello',
              lessonId: 'hi_hello',
              title: 'Greetings',
              objective: 'Greet someone',
              order: 0,
            ),
          ],
        ),
      ],
    );

    await repository.saveCourse(course);
    expect(repository.getCourse(LearnLanguage.hindi), course);
  });

  test('corrupt or cross-language courses are ignored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersonalizedCourseRepository.courseKey(LearnLanguage.hindi): '{bad json',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = PersonalizedCourseRepository(
        ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      ).read(localStorageServiceProvider),
    );
    expect(repository.getCourse(LearnLanguage.hindi), isNull);
  });
}
