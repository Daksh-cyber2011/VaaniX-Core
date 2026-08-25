import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

void main() {
  group('Dart fallback quiz bank grounding', () {
    final all = chapterQuizzes.values.expand((e) => e).toList();

    test('has at least 20 grounded questions', () {
      expect(all.length, greaterThanOrEqualTo(20));
    });

    test('question ids are globally unique', () {
      final ids = all.map((q) => q.id).toSet();
      expect(ids.length, all.length);
    });

    test('every chapter has a usable question set (>= 6)', () {
      chapterQuizzes.forEach((chapterId, questions) {
        expect(questions.length, greaterThanOrEqualTo(6),
            reason: '$chapterId needs more questions');
      });
    });

    test('options are well-formed for every question', () {
      for (final q in all) {
        expect(q.options.length, greaterThanOrEqualTo(2), reason: q.id);
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
            reason: q.id);
        expect(q.chapterId, isNotEmpty, reason: q.id);
      }
    });

    test('difficulty tags are derived from the chapter lesson bands', () {
      final bands = <String, Set<Difficulty>>{};
      for (final chapter in sanskritCurriculum) {
        bands[chapter.id] = chapter.lessons.map((l) => l.difficulty).toSet();
      }
      for (final entry in chapterQuizzes.entries) {
        final allowed = bands[entry.key] ?? const <Difficulty>{};
        for (final q in entry.value) {
          expect(allowed.contains(q.difficulty), isTrue,
              reason: '${q.id} difficulty ${q.difficulty.name} is not in the '
                  'lesson bands ${allowed.map((d) => d.name)} of ${entry.key}');
        }
      }
    });
  });

  group('v1.json source grounding', () {
    final file = File('assets/curriculum/v1.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final quizzes = (json['quizzes'] as List).cast<Map<String, dynamic>>();

    test('json parses and holds every chapter', () {
      expect(
          quizzes.map((q) => q['chapterId']), containsAll(chapterQuizzes.keys));
    });

    test('json ids + difficulties match the Dart map exactly', () {
      final dartById = {
        for (final q in chapterQuizzes.values.expand((e) => e))
          q.id: q.difficulty.name,
      };
      var jsonCount = 0;
      for (final quiz in quizzes) {
        for (final q
            in (quiz['questions'] as List).cast<Map<String, dynamic>>()) {
          final id = q['id'] as String;
          jsonCount += 1;
          expect(dartById.containsKey(id), isTrue, reason: 'unknown id $id');
          expect(q['difficulty'], dartById[id],
              reason: 'difficulty mismatch for $id');
        }
      }
      expect(jsonCount, dartById.length);
    });

    test('every json question decodes through QuizQuestion.fromJson', () {
      for (final quiz in quizzes) {
        for (final q
            in (quiz['questions'] as List).cast<Map<String, dynamic>>()) {
          final decoded = QuizQuestion.fromJson(q);
          expect(decoded.id, isNotEmpty);
          expect(decoded.options.length, greaterThanOrEqualTo(2));
          expect(decoded.correctIndex, lessThan(decoded.options.length));
        }
      }
    });
  });
}
