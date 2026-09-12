/// Exam Mode 2.0 — Adaptive Diagnostic Engine (M4, §11)
///
/// The adaptive controller (pure Dart, fully testable):
///  * starts at MEDIUM difficulty for every student;
///  * a CORRECT answer moves the next question HARDER (max tier 3);
///  * a WRONG answer moves the next question EASIER (min tier 1) —
///    when weak, the engine probes prerequisite-level understanding;
///  * topic selection is COVERAGE-FIRST: topics with the fewest
///    attempts so far are probed before revisiting known ones;
///  * the session ends after [maxItems] questions (§10: 5–10 minutes,
///    so maxItems is bounded 5..15) or when every topic has ≥2
///    responses;
///  * the engine NEVER decides curriculum content — it only picks and
///    grades from a pre-validated, syllabus-grounded question bank.
///
/// Report generation converts responses into per-topic qualitative
/// bands and observation sentences (§10): specific, honest, and free
/// of percentages (§30).
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/domain/diagnostic/exam_diagnostic_models.dart';

/// In-session state of one running diagnostic.
class DiagnosticSessionState extends Equatable {
  const DiagnosticSessionState({
    required this.servedQuestions,
    required this.responses,
    required this.current,
    required this.finished,
  });

  /// All questions served so far (in order).
  final List<DiagnosticQuestion> servedQuestions;
  final List<DiagnosticResponse> responses;

  /// The question the student should answer now; null when finished.
  final DiagnosticQuestion? current;
  final bool finished;

  int get answeredCount => responses.length;
  int get correctCount => responses.where((r) => r.correct).length;

  @override
  List<Object?> get props => [servedQuestions, responses, finished];
}

/// The adaptive engine.
class ExamDiagnosticEngine {
  ExamDiagnosticEngine({
    required this.topicTitles,
    required this.topicSections,
    this.maxItems = 10,
  })  : assert(maxItems >= 5 && maxItems <= 15, '§10: 5–10 minutes'),
        _bank = {};

  /// topicId → display title (for observations).
  final Map<String, String> topicTitles;

  /// topicId → section title (for observations).
  final Map<String, String> topicSections;

  /// Question budget (default 10 ≈ 5–8 minutes).
  final int maxItems;

  final Map<DiagnosticDifficulty, List<DiagnosticQuestion>> _bank;

  /// Registers the grounded question bank (from the data layer).
  void registerBank(List<DiagnosticQuestion> questions) {
    _bank.clear();
    for (final q in questions) {
      if (!q.isValid) continue; // never serve malformed data
      _bank.putIfAbsent(q.difficulty, () => []).add(q);
    }
  }

  /// Starts a fresh session at MEDIUM difficulty (§11: no assumptions
  /// about the student before evidence exists). When the course's bank
  /// has no medium tier at all, the nearest LOWER tier is used — the
  /// student is never punished with harder-than-medium sight-unseen.
  DiagnosticSessionState start() {
    var first = _pickNext(
      difficulty: DiagnosticDifficulty.medium,
      served: const <String>{},
      attemptsByTopic: const <String, int>{},
    );
    first ??= _pickNext(
      difficulty: DiagnosticDifficulty.easy,
      served: const <String>{},
      attemptsByTopic: const <String, int>{},
    );
    first ??= _pickNext(
      difficulty: DiagnosticDifficulty.hard,
      served: const <String>{},
      attemptsByTopic: const <String, int>{},
    );
    return DiagnosticSessionState(
      servedQuestions: first == null ? const [] : [first],
      responses: const [],
      current: first,
      finished: first == null,
    );
  }

  /// Records the answer to [state.current] and advances adaptively.
  /// [selectedIndex] -1 = skipped (counts as not-correct, §10 honest).
  DiagnosticSessionState answer(
      DiagnosticSessionState state, int selectedIndex) {
    final q = state.current;
    if (q == null || state.finished) return state;

    final response = DiagnosticResponse(
      questionId: q.id,
      topicId: q.topicId,
      selectedIndex: selectedIndex,
      correct: selectedIndex == q.correctIndex,
      difficulty: q.difficulty,
      skill: q.skill,
    );
    final responses = [...state.responses, response];

    // §11 adaptive ladder: correct → harder, wrong/skip → easier.
    final nextDifficulty =
        response.correct ? _tierUp(q.difficulty) : _tierDown(q.difficulty);

    final attemptsByTopic = <String, int>{};
    for (final r in responses) {
      attemptsByTopic[r.topicId] = (attemptsByTopic[r.topicId] ?? 0) + 1;
    }

    final done =
        responses.length >= maxItems || _allTopicsProbed(attemptsByTopic);
    if (done) {
      return DiagnosticSessionState(
        servedQuestions: state.servedQuestions,
        responses: responses,
        current: null,
        finished: true,
      );
    }

    final served = state.servedQuestions.map((q) => q.id).toSet();
    // Preferred tier first, then NEAREST tiers (never a hard→easy jump
    // when the preferred pool is exhausted — §11 smooth ladder).
    // Do not reverse the demonstrated direction merely to fill the budget.
    // If the matching tier is exhausted, ending honestly is safer than
    // presenting a question outside the learner's demonstrated level.
    for (final tier in _tierOrder(
      nextDifficulty,
      movingUp: response.correct,
    )) {
      final next = _pickNext(
        difficulty: tier,
        served: served,
        attemptsByTopic: attemptsByTopic,
      );
      if (next != null) {
        return DiagnosticSessionState(
          servedQuestions: [...state.servedQuestions, next],
          responses: responses,
          current: next,
          finished: false,
        );
      }
    }
    return DiagnosticSessionState(
      servedQuestions: state.servedQuestions,
      responses: responses,
      current: null,
      finished: true,
    );
  }

  /// Same tier first, adjacent tier second, far tier last (clamped).
  /// For MEDIUM, the adjacent preference is EASY (a student is never
  /// escalated above their demonstrated level just because a pool
  /// ran empty).
  List<DiagnosticDifficulty> _tierOrder(
    DiagnosticDifficulty d, {
    required bool movingUp,
  }) =>
      switch ((d, movingUp)) {
        (DiagnosticDifficulty.hard, _) => const [DiagnosticDifficulty.hard],
        (DiagnosticDifficulty.medium, true) => const [
            DiagnosticDifficulty.medium,
            DiagnosticDifficulty.hard,
          ],
        (DiagnosticDifficulty.medium, false) => const [
            DiagnosticDifficulty.medium,
            DiagnosticDifficulty.easy,
          ],
        (DiagnosticDifficulty.easy, _) => const [DiagnosticDifficulty.easy],
      };

  /// Builds the final report from a finished session.
  ///
  /// Ability math (engine-only): weighted accuracy where a correct
  /// HARD answer is worth more than a correct EASY one (1.0 / 1.2 / 1.5
  /// by tier). Bands: ≥0.75 strong, ≥0.5 learning, else needsAttention.
  /// The STUDENT only ever sees bands + observation sentences (§30).
  DiagnosticReport buildReport(DiagnosticSessionState state) {
    final byTopic = <String, List<DiagnosticResponse>>{};
    for (final r in state.responses) {
      byTopic.putIfAbsent(r.topicId, () => []).add(r);
    }

    final estimates = <TopicEstimate>[];
    byTopic.forEach((topicId, rs) {
      var weightSum = 0.0;
      var scoreSum = 0.0;
      for (final r in rs) {
        final w = _difficultyWeight(r.difficulty);
        weightSum += w;
        if (r.correct) scoreSum += w;
      }
      final ability = weightSum == 0 ? 0.0 : scoreSum / weightSum;
      estimates.add(TopicEstimate(
        topicId: topicId,
        topicTitle: topicTitles[topicId] ?? topicId,
        sectionTitle: topicSections[topicId] ?? '',
        attempts: rs.length,
        correct: rs.where((r) => r.correct).length,
        band: _bandFor(ability),
      ));
    });

    // Overall: unweighted mean of abilities, still qualitative.
    final overallAbility = estimates.isEmpty
        ? 0.0
        : estimates.map((e) {
              var w = 0.0, s = 0.0;
              for (final r in byTopic[e.topicId]!) {
                final d = _difficultyWeight(r.difficulty);
                w += d;
                if (r.correct) s += d;
              }
              return w == 0 ? 0.0 : s / w;
            }).reduce((a, b) => a + b) /
            estimates.length;

    return DiagnosticReport(
      trackId: '',
      completedAtIso: DateTime.now().toIso8601String(),
      responses: state.responses,
      topicEstimates: estimates,
      overallBand: _bandFor(overallAbility),
      observations: _observations(estimates, byTopic),
    );
  }

  /// Specific, constructive observation sentences (§10 examples).
  List<String> _observations(List<TopicEstimate> estimates,
      Map<String, List<DiagnosticResponse>> byTopic) {
    if (estimates.isEmpty) {
      return ['अभी कोई आकलन नहीं — कुछ प्रश्न ज़रूर हल करें।'];
    }
    final obs = <String>[];
    final strong = estimates.where((e) => e.band == TopicBand.strong).toList();
    final attention =
        estimates.where((e) => e.band == TopicBand.needsAttention).toList();
    final learning =
        estimates.where((e) => e.band == TopicBand.learning).toList();

    if (strong.isNotEmpty) {
      obs.add('मज़बूत: ${strong.map((e) => e.topicTitle).take(3).join(', ')} — '
          'इन्हें बनाए रखें।');
    }
    if (learning.isNotEmpty) {
      obs.add(
          'सीख रहे हैं: ${learning.map((e) => e.topicTitle).take(3).join(', ')} — '
          'अभ्यास जारी रखें।');
    }
    if (attention.isNotEmpty) {
      obs.add(
          'ध्यान चाहिए: ${attention.map((e) => e.topicTitle).take(3).join(', ')} — '
          'योजना इनसे शुरू होगी।');
    }
    // Skill-level observation (§10: grammar/application dimensions).
    final apply = <DiagnosticResponse>[];
    byTopic.forEach((_, rs) => apply.addAll(rs));
    final applyRs =
        apply.where((r) => r.skill == DiagnosticSkill.application).toList();
    if (applyRs.length >= 2) {
      final ok = applyRs.where((r) => r.correct).length;
      if (ok == applyRs.length) {
        obs.add('अनुप्रयोग (application) प्रश्नों में अच्छी पकड़।');
      } else if (ok == 0) {
        obs.add('अनुप्रयोग वाले प्रश्नों पर ध्यान देना होगा।');
      }
    }
    return obs;
  }

  TopicBand _bandFor(double ability) {
    if (ability >= 0.75) return TopicBand.strong;
    if (ability >= 0.5) return TopicBand.learning;
    return TopicBand.needsAttention;
  }

  double _difficultyWeight(DiagnosticDifficulty d) => switch (d) {
        DiagnosticDifficulty.easy => 1.0,
        DiagnosticDifficulty.medium => 1.2,
        DiagnosticDifficulty.hard => 1.5,
      };

  DiagnosticDifficulty _tierUp(DiagnosticDifficulty d) => switch (d) {
        DiagnosticDifficulty.hard => DiagnosticDifficulty.hard,
        DiagnosticDifficulty.medium => DiagnosticDifficulty.hard,
        DiagnosticDifficulty.easy => DiagnosticDifficulty.medium,
      };

  DiagnosticDifficulty _tierDown(DiagnosticDifficulty d) => switch (d) {
        DiagnosticDifficulty.hard => DiagnosticDifficulty.medium,
        DiagnosticDifficulty.medium => DiagnosticDifficulty.easy,
        DiagnosticDifficulty.easy => DiagnosticDifficulty.easy,
      };

  DiagnosticQuestion? _pickNext({
    required DiagnosticDifficulty difficulty,
    required Set<String> served,
    required Map<String, int> attemptsByTopic,
  }) {
    final pool = _bank[difficulty];
    if (pool == null || pool.isEmpty) return null;
    // Coverage-first: prefer topics with the fewest responses so far
    // (§11: enough dimensions for a useful profile, not 50 questions).
    final ranked = pool.where((q) => !served.contains(q.id)).toList()
      ..sort((a, b) => (attemptsByTopic[a.topicId] ?? 0)
          .compareTo(attemptsByTopic[b.topicId] ?? 0));
    return ranked.isEmpty ? null : ranked.first;
  }

  bool _allTopicsProbed(Map<String, int> attemptsByTopic) {
    if (topicTitles.isEmpty) return false;
    for (final t in topicTitles.keys) {
      if ((attemptsByTopic[t] ?? 0) < 2) return false;
    }
    return true;
  }
}
