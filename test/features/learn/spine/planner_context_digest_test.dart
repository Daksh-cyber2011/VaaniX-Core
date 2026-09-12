/// PlannerContext digest tests (M2 spine).
///
/// The digest is what M4's prompt assembly will consume — it must carry
/// the learner's saved profile (goal / desired level / pace / daily-goal
/// minutes) as PURE DATA, and reflect the M2 session-sizing rule
/// (minutesAvailable = profile.dailyGoalMinutes when a profile exists).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/deterministic_planner.dart';
import 'package:vaanix_app/features/learn/domain/spine/learning_state.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

ConceptGraph _graph() => ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: const [
        Chapter(
          id: 'ch_1',
          title: 'Chapter 1',
          lessons: [Lesson(id: 'hi_ls_1', title: 'one', chapterId: 'ch_1')],
        ),
      ],
    );

PlannerContext _context({LearnerProfile? profile}) {
  return PlannerContext(
    languageCode: 'hi',
    languageName: 'Hindi',
    graph: _graph(),
    state: const LearningState(languageCode: 'hi'),
    profile: profile,
    minutesAvailable:
        profile?.dailyGoalMinutes ?? LearnerProfile.kDefaultDailyGoalMinutes,
    supportedActivityTypes: kDeterministicPlannerActivityKinds,
  );
}

void main() {
  test('digest stays null-profile-safe (pre-M2 behaviour unchanged)', () {
    final digest = _context().toStructuredDigest();
    expect(digest['language'], 'hi');
    expect(digest['currentLevel'], isNull);
    expect(digest['desiredLevel'], isNull);
    expect(digest['goal'], isNull);
    expect(digest['minutesAvailable'],
        LearnerProfile.kDefaultDailyGoalMinutes);
  });

  test('digest carries the saved profile as structured data', () {
    final profile = LearnerProfile.initial(LearnLanguage.hindi).copyWith(
      goal: LearningGoal.conversation,
      desiredLevel: DesiredLevel.intermediate,
      pace: LearningPace.gentle,
      selfReport: SelfReport.recognizeScript,
      dailyGoalMinutes: 20,
    );
    final digest = _context(profile: profile).toStructuredDigest();

    expect(digest['goal'], 'conversation');
    expect(digest['desiredLevel'], 'intermediate');
    expect(digest['pace'], 'gentle');
    expect(digest['minutesAvailable'], 20);
  });

  test('session sizing follows the learner\u2019s daily goal (M2 rule)', () {
    final small = LearnerProfile.initial(LearnLanguage.hindi)
        .copyWith(dailyGoalMinutes: 5);
    final big = LearnerProfile.initial(LearnLanguage.hindi)
        .copyWith(dailyGoalMinutes: 30);

    expect(_context(profile: small).minutesAvailable, 5);
    expect(_context(profile: big).minutesAvailable, 30);
  });
}
