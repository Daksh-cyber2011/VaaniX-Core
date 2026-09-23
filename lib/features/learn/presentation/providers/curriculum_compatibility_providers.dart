/// Learn curriculum content-revision compatibility boundary.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/data/learn_plan_repository.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';

/// Ensures curriculum-bound state is compatible before Learn consumers use it.
///
/// The new revision is written LAST. A failed cleanup therefore leaves the old
/// revision marker in place and retries on the next access.
final curriculumCompatibilityProvider =
    FutureProvider.family<void, LearnLanguage>((ref, language) async {
  final storage = ref.watch(localStorageServiceProvider);
  final profile = LearnProfileRepository(storage);
  final plans = LearnPlanRepository(storage);
  final generated = GeneratedContentRepository(storage);
  final current = learnLanguageSpec(language).curriculumRevision;
  final stored = profile.getCurriculumRevision(language);

  // Existing installs adopt the first explicit marker without destructive
  // migration: their learner data predates this compatibility boundary.
  if (stored == null || stored == current) {
    if (stored == null) {
      await profile.saveCurriculumRevision(language, current);
    }
    return;
  }

  await profile.clearLearningState(language);
  await profile.clearDiagnostic(language);

  final learnerProfile = profile.getProfile(language);
  if (learnerProfile != null && learnerProfile.currentLevel != null) {
    await profile.saveProfile(learnerProfile.copyWith(clearCurrentLevel: true));
  }

  await plans.clearPlan(language);
  await generated.clear(language);

  // Persist only after every curriculum-bound cleanup has completed.
  await profile.saveCurriculumRevision(language, current);
});
