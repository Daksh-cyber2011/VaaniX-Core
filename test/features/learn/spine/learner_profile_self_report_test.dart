/// LearnerProfile self-report + persistence-shape tests (M2 spine).
///
/// Pins: SelfReport labels + suggested-level hints (never shown as a
/// level), backward-compatible JSON (pre-M2 profiles without the
/// selfReport field still load), full round-trip with the new field, and
/// defensive parsing of unknown enum names.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/learner_profile.dart';

void main() {
  group('SelfReport', () {
    test('covers the brief\u2019s example statements', () {
      // Master Brief §10 examples map onto the four coarse options.
      expect(SelfReport.almostNothing.label, contains('almost nothing'));
      expect(SelfReport.recognizeScript.label, contains('read the script'));
      expect(SelfReport.understandBasics.label, contains('basics'));
      expect(SelfReport.conversational.label, contains('chat'));
    });

    test('suggested level is a coarse hint, never a real level claim', () {
      expect(SelfReport.almostNothing.suggestedLevel, 0);
      expect(SelfReport.recognizeScript.suggestedLevel, 1);
      expect(SelfReport.understandBasics.suggestedLevel, 1);
      expect(SelfReport.conversational.suggestedLevel, 2);
      // Hint stays inside the internal 0..4 scale.
      for (final s in SelfReport.values) {
        expect(s.suggestedLevel, inInclusiveRange(0, 4));
      }
    });

    test('tryParse degrades unknown names to null', () {
      expect(SelfReport.tryParse('conversational'), SelfReport.conversational);
      expect(SelfReport.tryParse('fluent_in_klingon'), isNull);
      expect(SelfReport.tryParse(null), isNull);
    });
  });

  group('LearnerProfile JSON backward compatibility (M2 field)', () {
    test('pre-M2 profile JSON (no selfReport) still loads', () {
      final legacy = {
        'language': 'hindi',
        'desiredLevel': 'intermediate',
        'goal': 'travel',
        'dailyGoalMinutes': 15,
      };
      final profile = LearnerProfile.fromJson(legacy);
      expect(profile.selfReport, SelfReport.almostNothing); // safe default
      expect(profile.goal, LearningGoal.travel);
      expect(profile.dailyGoalMinutes, 15);
    });

    test('full round-trip keeps the self-report', () {
      final profile = LearnerProfile.initial(LearnLanguage.tamil).copyWith(
        selfReport: SelfReport.recognizeScript,
        goal: LearningGoal.conversation,
      );
      final restored = LearnerProfile.fromJson(
          jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>);
      expect(restored.selfReport, SelfReport.recognizeScript);
      expect(restored.goal, LearningGoal.conversation);
      expect(restored.language, LearnLanguage.tamil);
    });

    test('unknown selfReport name falls back to almostNothing', () {
      final profile = LearnerProfile.fromJson({
        'language': 'urdu',
        'selfReport': 'native_speaker',
      });
      expect(profile.selfReport, SelfReport.almostNothing);
      expect(profile.language, LearnLanguage.urdu);
    });
  });

  group('enum catalogues match the Master Brief', () {
    test('goals cover §28 options', () {
      expect(
          LearningGoal.values.map((g) => g.name),
          containsAll([
            'general',
            'conversation',
            'reading',
            'writing',
            'travel',
            'school',
            'culture',
            'mastery',
          ]));
    });

    test('desired levels cover §29 ladder with clear labels', () {
      expect(
        DesiredLevel.values.map((d) => d.label),
        ['Starter', 'Beginner', 'Elementary', 'Intermediate', 'Advanced'],
      );
    });
  });
}
