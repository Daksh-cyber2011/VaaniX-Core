/// Learn Mode 2.0 — Concept Graph (M1 Architecture Spine)
///
/// Maps the EXISTING static curricula into the Master Brief §49 learning
/// graph without rewriting any content:
///
///   Language → Skill → Concept → Content → Exercise → Mastery → Milestone
///
/// Derivation contract (deterministic, grounded in the JSON the app already
/// ships):
/// - one [ConceptSkill] per curriculum chapter (chapters are the trusted
///   thematic groupings);
/// - one [LearnConcept] per curriculum lesson, linked back to its lesson id
///   so trusted content stays addressable;
/// - prerequisites follow the curriculum's own pedagogical order: within a
///   chapter each concept requires its predecessor; the first concept of a
///   chapter requires the final concept of the previous chapter. A–G
///   curricula are authored as ordered journeys, so this is the honest M1
///   mapping — M9's per-language knowledge layer can refine it later.
///
/// The graph is the trusted knowledge boundary the planner validates AI
/// decisions against (Master Brief §14): a concept that is not in the graph
/// does not exist and can never drive navigation.
///
/// Pure Dart; no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/learn/domain/spine/mastery.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

/// A skill dimension grouping concepts (Master Brief §49 "Skill" level).
///
/// M1 derives one skill per curriculum chapter; the chapter's stable id is
/// reused as the skill id so mappings never drift.
class ConceptSkill extends Equatable {
  const ConceptSkill({
    required this.id,
    required this.title,
    required this.order,
    this.subtitle,
  });

  /// Stable id — identical to the source chapter id (e.g. `hi_ch1`).
  final String id;

  final String title;
  final String? subtitle;

  /// Ordering within the language (from the chapter's own order field).
  final int order;

  @override
  List<Object?> get props => [id, title, subtitle, order];
}

/// One teachable concept node (Master Brief §49 "Concept" level).
///
/// M1 derives concepts from lessons — the lesson remains the trusted
/// content anchor ([lessonId]) while the concept gives the planner a
/// stable, lesson-independent handle.
class LearnConcept extends Equatable {
  const LearnConcept({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.skillId,
    required this.lessonId,
    required this.difficulty,
    required this.order,
    this.subtitle,
    this.prerequisites = const <String>[],
  });

  /// Stable concept id. M1 uses the lesson id itself (globally unique per
  /// language bank: `hi_*`, `bn_*`, …) so concept ↔ lesson resolution is
  /// O(1) and drift-free. A future schema can decouple the two ids.
  final String id;

  final String title;
  final String? subtitle;

  /// ISO 639-1 code of the owning language (`'hi'`, `'ur'`, …).
  final String languageCode;

  /// Owning [ConceptSkill.id].
  final String skillId;

  /// The trusted content this concept is anchored to.
  final String lessonId;

  /// Difficulty band inherited from the lesson.
  final Difficulty difficulty;

  /// Global curriculum order (chapter order × 1000 + lesson position).
  final int order;

  /// Concept ids that should be [MasteryStage.practiced]+ before this
  /// concept is unlocked (derived from curriculum order; see library docs).
  final List<String> prerequisites;

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        languageCode,
        skillId,
        lessonId,
        difficulty,
        order,
        prerequisites,
      ];
}

/// The trusted, language-scoped knowledge graph.
///
/// Not `const`-constructible by design: it memoizes a lazy lookup index.
class ConceptGraph extends Equatable {
  ConceptGraph({
    required this.languageCode,
    required this.skills,
    required this.concepts,
  }) : _idIndex = {for (final c in concepts) c.id: c};

  /// ISO 639-1 code of the language this graph describes
  /// (`'sa'` for the legacy Sanskrit track — see [forCurriculum]).
  final String languageCode;

  final List<ConceptSkill> skills;

  /// All concepts, ordered by [LearnConcept.order].
  final List<LearnConcept> concepts;

  bool get isEmpty => concepts.isEmpty;
  bool get isNotEmpty => concepts.isNotEmpty;

  /// Builds the graph from a loaded curriculum.
  ///
  /// Defensive by design: duplicate lesson ids keep the FIRST occurrence,
  /// empty chapters produce no skill, and a fully empty curriculum produces
  /// an empty graph (stub languages kn/ml/or) — never an exception.
  factory ConceptGraph.forCurriculum({
    required String languageCode,
    required List<Chapter> chapters,
  }) {
    final skills = <ConceptSkill>[];
    final concepts = <LearnConcept>[];
    final seenConceptIds = <String>{};
    String? previousSkillLastConceptId;

    final orderedChapters = [...chapters]..sort(
        (a, b) => a.order != b.order
            ? a.order.compareTo(b.order)
            : a.id.compareTo(b.id),
      );

    for (final chapter in orderedChapters) {
      if (chapter.lessons.isEmpty) continue;
      skills.add(ConceptSkill(
        id: chapter.id,
        title: chapter.title,
        subtitle: chapter.subtitle,
        order: chapter.order,
      ));

      String? previousConceptId = previousSkillLastConceptId;
      for (var i = 0; i < chapter.lessons.length; i++) {
        final lesson = chapter.lessons[i];
        if (seenConceptIds.contains(lesson.id)) continue;
        seenConceptIds.add(lesson.id);

        final prereqs = <String>[
          if (previousConceptId != null) previousConceptId,
        ];
        concepts.add(LearnConcept(
          id: lesson.id,
          title: lesson.title,
          subtitle: lesson.subtitle,
          languageCode: languageCode,
          skillId: chapter.id,
          lessonId: lesson.id,
          difficulty: lesson.difficulty,
          order: chapter.order * 1000 + i,
          prerequisites: prereqs,
        ));
        previousConceptId = lesson.id;
      }
      previousSkillLastConceptId = previousConceptId;
    }

    concepts.sort((a, b) => a.order.compareTo(b.order));
    return ConceptGraph(
      languageCode: languageCode,
      skills: List.unmodifiable(skills),
      concepts: List.unmodifiable(concepts),
    );
  }

  LearnConcept? conceptById(String conceptId) => _byId()[conceptId];

  /// Resolves the concept anchored to a trusted lesson id.
  LearnConcept? conceptForLesson(String lessonId) => _byId()[lessonId];

  /// All concepts belonging to one skill, in curriculum order.
  List<LearnConcept> conceptsInSkill(String skillId) =>
      [for (final c in concepts) if (c.skillId == skillId) c];

  /// The first concept that has not reached [atLeast] for the learner,
  /// in curriculum order. `null` when everything reached it (or graph is
  /// empty). This is the deterministic "next concept" rule.
  LearnConcept? nextUnmastered(Map<String, MasteryStage> stages,
      {MasteryStage atLeast = MasteryStage.introduced}) {
    for (final c in concepts) {
      final stage = stages[c.id];
      if (stage == null || !stage.isAtLeast(atLeast)) return c;
    }
    return null;
  }

  /// True when every [LearnConcept.prerequisites] of [conceptId] has
  /// reached [atLeast]. A concept with no prerequisites is always
  /// unlocked. Unknown concepts are locked (fail-closed: the planner must
  /// not navigate to something the graph does not know).
  bool isUnlocked(
    String conceptId,
    Map<String, MasteryStage> stages, {
    MasteryStage atLeast = MasteryStage.practiced,
  }) {
    final concept = conceptById(conceptId);
    if (concept == null) return false;
    for (final preId in concept.prerequisites) {
      final stage = stages[preId];
      if (stage == null || !stage.isAtLeast(atLeast)) return false;
    }
    return true;
  }

  /// Transitive prerequisite closure of [conceptId] (excluding itself),
  /// cycle-safe. Unknown concept → empty list.
  List<String> prerequisiteClosureOf(String conceptId) {
    final closure = <String>[];
    final visited = <String>{conceptId};
    final queue = <String>[...?conceptById(conceptId)?.prerequisites];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!visited.add(id)) continue;
      closure.add(id);
      queue.addAll(conceptById(id)?.prerequisites ?? const <String>[]);
    }
    return closure;
  }

  // Eagerly-built lookup index (immutable after construction).
  final Map<String, LearnConcept> _idIndex;

  Map<String, LearnConcept> _byId() => _idIndex;

  @override
  List<Object?> get props => [languageCode, skills, concepts];
}
