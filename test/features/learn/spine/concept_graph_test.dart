/// Learn Mode 2.0 — Concept Graph derivation tests (M1 spine).
///
/// Proves the M1 old→new mapping on REAL curriculum data: the Hindi JSON
/// asset (5 chapters / 20 lessons) becomes a Language→Skill→Concept graph
/// with a faithful prerequisite chain, and stub/empty curricula produce a
/// safe empty graph. Pure Dart — no widget binding, assets read from disk
/// (same pattern as the per-language curriculum tests).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/learn/domain/spine/concept_graph.dart';
import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

List<Chapter> _loadChapters(String code) {
  final file = File('assets/curriculum/learn/$code.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final chaptersJson = json['chapters'] as List<dynamic>? ?? [];
  return chaptersJson
      .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  group('ConceptGraph from the REAL Hindi curriculum', () {
    final graph = ConceptGraph.forCurriculum(
      languageCode: 'hi',
      chapters: _loadChapters('hi'),
    );

    test('every chapter becomes a skill and every lesson a concept', () {
      expect(graph.skills, hasLength(5));
      expect(graph.concepts, hasLength(20));
      expect(graph.isNotEmpty, isTrue);
    });

    test('concept ids are unique and mirror the lesson ids', () {
      final ids = graph.concepts.map((c) => c.id).toSet();
      expect(ids.length, graph.concepts.length);
      for (final concept in graph.concepts) {
        expect(concept.lessonId, concept.id);
        expect(concept.languageCode, 'hi');
      }
    });

    test('concepts are ordered and prerequisites form one grounded chain', () {
      final orders = graph.concepts.map((c) => c.order).toList();
      expect(orders, orders.toList()..sort());

      // First concept: no prerequisites.
      expect(graph.concepts.first.prerequisites, isEmpty);

      // Every other concept requires exactly its in-order predecessor.
      for (var i = 1; i < graph.concepts.length; i++) {
        expect(graph.concepts[i].prerequisites, [graph.concepts[i - 1].id]);
      }
    });

    test('lookup + unlock helpers behave', () {
      final first = graph.concepts.first;
      final second = graph.concepts[1];

      expect(graph.conceptById(first.id), isNotNull);
      expect(graph.conceptForLesson(first.lessonId)!.id, first.id);
      expect(graph.conceptById('nope_nope'), isNull);

      // Nothing mastered → only the first concept is unlocked.
      expect(graph.isUnlocked(first.id, const {}), isTrue);
      expect(graph.isUnlocked(second.id, const {}), isFalse);
      // First introduced (not practiced) → second stays locked.
      expect(graph.isUnlocked(second.id, {first.id: MasteryStage.introduced}),
          isFalse);
      // First practiced → second unlocks.
      expect(graph.isUnlocked(second.id, {first.id: MasteryStage.practiced}),
          isTrue);
      // Unknown concept fails CLOSED.
      expect(graph.isUnlocked('nope_nope', {}), isFalse);
    });

    test('nextUnmastered walks the curriculum order', () {
      final stages = <String, MasteryStage>{
        for (final c in graph.concepts.take(3)) c.id: MasteryStage.understood,
      };
      expect(graph.nextUnmastered(stages)!.id, graph.concepts[3].id);
    });

    test('prerequisite closure is transitive and cycle-safe', () {
      final third = graph.concepts[2];
      final closure = graph.prerequisiteClosureOf(third.id);
      expect(
          closure, containsAll([graph.concepts[0].id, graph.concepts[1].id]));
      expect(closure.contains(third.id), isFalse);
    });
  });

  group('ConceptGraph defensive edges', () {
    test('empty curriculum produces an empty, non-crashing graph', () {
      final graph = ConceptGraph.forCurriculum(
        languageCode: 'kn',
        chapters: const [],
      );
      expect(graph.isEmpty, isTrue);
      expect(graph.concepts, isEmpty);
      expect(graph.conceptById('anything'), isNull);
      expect(graph.isUnlocked('anything', const {}), isFalse);
    });

    test('duplicate lesson ids keep the first occurrence', () {
      final chapters = [
        const Chapter(
          id: 'ch_a',
          title: 'A',
          lessons: [
            Lesson(id: 'ls_1', title: 'one', chapterId: 'ch_a'),
          ],
        ),
        const Chapter(
          id: 'ch_b',
          title: 'B',
          lessons: [
            Lesson(id: 'ls_1', title: 'dup', chapterId: 'ch_b'),
            Lesson(id: 'ls_2', title: 'two', chapterId: 'ch_b'),
          ],
        ),
      ];
      final graph = ConceptGraph.forCurriculum(
        languageCode: 'xx',
        chapters: chapters,
      );
      expect(graph.concepts, hasLength(2));
      expect(graph.conceptById('ls_1')!.skillId, 'ch_a');
    });

    test('chapters without lessons are skipped entirely', () {
      final graph = ConceptGraph.forCurriculum(
        languageCode: 'xx',
        chapters: const [
          Chapter(id: 'empty', title: 'Empty'),
          Chapter(
            id: 'real',
            title: 'Real',
            lessons: [Lesson(id: 'ls_9', title: 'nine', chapterId: 'real')],
          ),
        ],
      );
      expect(graph.skills.map((s) => s.id), ['real']);
      expect(graph.concepts.map((c) => c.id), ['ls_9']);
    });
  });
}
