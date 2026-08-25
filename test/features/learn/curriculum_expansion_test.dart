/// V1 Syllabus Expansion Tests
///
/// Guards the PRD 15 (CBSE Ruchira-aligned) syllabus expansion:
///  - authoritative chapter/lesson coverage (13 lessons, 4 chapters)
///  - JSON <-> Dart fallback parity for chapters AND lessons
///  - every lesson has grounded exercises
///  - every chapter is assessable in the exam bank

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/data/sanskrit_curriculum.dart';
import 'package:vaanix_app/features/learn/data/sanskrit_exercises.dart';
import 'package:vaanix_app/features/learn/data/unit2_lesson_content.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// Authoritative V1 syllabus (PRD 15 - CBSE Ruchira Units 1-4, Section A).
const Map<String, List<String>> kSyllabus = {
  'ch_alphabet': [
    'ls_alphabet_vowels', // Unit 1: Devanagari Foundation - vowels
    'ls_alphabet_consonants', // Unit 1: consonants
    'ls_alphabet_barakhadi', // Unit 1: consonant + vowel
    'ls_alphabet_conjuncts', // Unit 1: conjunct consonants
  ],
  'ch_words': [
    'ls_words_greetings', // Unit 3: vocabulary - greetings
    'ls_words_family', // Unit 3: family words
    'ls_words_numbers', // Unit 3: numbers 1-20
  ],
  'ch_sentences': [
    'ls_sentences_intro', // Unit 4: introducing yourself
    'ls_sentences_questions', // Unit 4: asking questions
    'ls_sentences_translation', // Unit 4: translation (SOV)
  ],
  'ch_grammar': [
    'ls_grammar_nouns_cases', // Unit 2: nouns & cases (vibhakti)
    'ls_grammar_pronouns', // Unit 2: pronouns (sarvanam)
    'ls_grammar_verbs', // Unit 2: verbs (lakaras)
  ],
};

List<Lesson> get _allDartLessons =>
    sanskritCurriculum.expand((c) => c.lessons).toList();

Map<String, dynamic> _loadJson() =>
    jsonDecode(File('assets/curriculum/v1.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('Syllabus coverage', () {
    test('curriculum implements the full PRD 15 V1 lesson set', () {
      final byChapter = <String, List<String>>{};
      for (final chapter in sanskritCurriculum) {
        byChapter[chapter.id] = chapter.lessons.map((l) => l.id).toList();
      }
      expect(byChapter.keys.toSet(), kSyllabus.keys.toSet(),
          reason: 'chapters must match the authoritative syllabus');
      kSyllabus.forEach((chapterId, lessonIds) {
        expect(byChapter[chapterId], lessonIds,
            reason: 'lesson ids of $chapterId must match the syllabus');
      });
      expect(_allDartLessons.length, 13);
    });

    test('every chapter exposes a subtitle, order and ordered lessons', () {
      for (final chapter in sanskritCurriculum) {
        expect(chapter.subtitle, isNotNull, reason: chapter.id);
        final orders = chapter.lessons.map((l) => l.order).toList();
        expect(orders, List<int>.generate(orders.length, (i) => i),
            reason: '${chapter.id} lessons must be ordered 0..n');
      }
    });

    test('unit2 content is registered for every new lesson', () {
      const newLessons = [
        'ls_alphabet_conjuncts',
        'ls_sentences_translation',
        'ls_grammar_nouns_cases',
        'ls_grammar_pronouns',
        'ls_grammar_verbs',
      ];
      for (final id in newLessons) {
        expect(unit2LessonContent.keys, contains(id),
            reason: '$id must have content in unit2_lesson_content.dart');
        expect(unit2LessonContent[id], isNotEmpty);
      }
    });
  });

  group('JSON <-> Dart fallback parity', () {
    final json = _loadJson();
    final jsonChapters =
        (json['chapters'] as List).cast<Map<String, dynamic>>();

    test('json chapters mirror the Dart chapter set and order', () {
      expect(jsonChapters.map((c) => c['id']).toList(),
          sanskritCurriculum.map((c) => c.id).toList());
    });

    test('json lessons mirror Dart lesson metadata exactly', () {
      final jsonLessons = <String, Map<String, dynamic>>{};
      for (final chapter in jsonChapters) {
        for (final lesson in chapter['lessons'] as List) {
          final l = lesson as Map<String, dynamic>;
          jsonLessons[l['id'] as String] = l;
        }
      }
      for (final lesson in _allDartLessons) {
        final jl = jsonLessons[lesson.id];
        expect(jl, isNotNull, reason: '${lesson.id} missing from v1.json');
        expect(jl!['chapterId'], lesson.chapterId, reason: lesson.id);
        expect(jl['order'], lesson.order, reason: lesson.id);
        expect(jl['xpReward'], lesson.xpReward, reason: lesson.id);
        expect(jl['difficulty'], lesson.difficulty.name, reason: lesson.id);
      }
    });

    test('json and Dart quiz banks agree on question ids and difficulties', () {
      final jsonQuizIds = <String>{};
      for (final group in json['quizzes'] as List) {
        for (final q in group['questions'] as List) {
          jsonQuizIds.add((q as Map<String, dynamic>)['id'] as String);
        }
      }
      final dartQuizIds =
          chapterQuizzes.values.expand((q) => q).map((q) => q.id).toSet();
      expect(jsonQuizIds, dartQuizIds);
    });
  });

  group('Exercise coverage', () {
    test('every curriculum lesson has grounded practice exercises', () {
      for (final lesson in _allDartLessons) {
        final ex = exercisesByLesson[lesson.id];
        expect(ex, isNotNull, reason: '${lesson.id} has no exercise list');
        expect(ex!.length, greaterThanOrEqualTo(1),
            reason: '${lesson.id} needs at least 1 exercise');
      }
    });

    test('every new lesson offers a full practice set of 4 exercises', () {
      const newLessons = [
        'ls_alphabet_conjuncts',
        'ls_sentences_translation',
        'ls_grammar_nouns_cases',
        'ls_grammar_pronouns',
        'ls_grammar_verbs',
      ];
      for (final id in newLessons) {
        final ex = exercisesByLesson[id]!;
        expect(ex.length, 4, reason: id);
        final types = ex.map((e) => e.type).toSet();
        expect(types, isNotEmpty, reason: id);
        for (final e in ex) {
          expect(e.lessonId, id, reason: '${e.id} lessonId mismatch');
        }
      }
    });
  });

  group('Exam bank coverage', () {
    test('every chapter is assessable with >= 6 grounded questions', () {
      for (final chapter in sanskritCurriculum) {
        final q = chapterQuizzes[chapter.id];
        expect(q, isNotNull, reason: '${chapter.id} has no quiz group');
        expect(q!.length, greaterThanOrEqualTo(6),
            reason: '${chapter.id} quiz group too small');
      }
    });

    test('new syllabus units are covered by the expanded bank (32 total)', () {
      final all = chapterQuizzes.values.expand((q) => q).toList();
      expect(all.length, 32);
      final ids = all.map((q) => q.id).toSet();
      for (final id in [
        'q_gram_1',
        'q_gram_2',
        'q_gram_3',
        'q_gram_4',
        'q_gram_5',
        'q_gram_6',
        'q_gram_7',
        'q_gram_8',
        'q_alpha_11',
        'q_alpha_12',
        'q_sent_7',
        'q_sent_8',
      ]) {
        expect(ids, contains(id), reason: '$id missing');
      }
      expect(ids.length, all.length, reason: 'ids must be unique');
    });
  });
}
