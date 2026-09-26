/// Local persistence for the validated personalized Learn roadmap.
library;

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/personalized_course.dart';

class PersonalizedCourseRepository {
  PersonalizedCourseRepository(this._storage);

  final ILocalStorageService _storage;

  static String courseKey(LearnLanguage language) =>
      'learn_profile_${learnLanguageSpec(language).code}_course';

  PersonalizedCourse? getCourse(LearnLanguage language) {
    final raw = _storage.getString(courseKey(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final course = PersonalizedCourse.fromJson(decoded);
      return course.languageCode == learnLanguageSpec(language).code
          ? course
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCourse(PersonalizedCourse course) async {
    final language = _languageForCode(course.languageCode);
    if (language == null) return;
    await _storage.setString(courseKey(language), jsonEncode(course.toJson()));
  }

  Future<void> clearCourse(LearnLanguage language) =>
      _storage.remove(courseKey(language));
}

LearnLanguage? _languageForCode(String code) {
  for (final spec in kLearnLanguageCatalogue) {
    if (spec.code == code) return spec.language;
  }
  return null;
}
