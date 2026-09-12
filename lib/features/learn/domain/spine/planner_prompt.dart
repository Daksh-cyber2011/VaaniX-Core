/// Learn Mode 2.0 — Planner Prompt Assembly (M4, Master Brief §62)
///
/// Structured prompt construction for the Gemini planner. The brief is
/// explicit: SEPARATE the prompt into
///
///   SYSTEM / PEDAGOGY RULES   → [buildPlannerSystemPrompt]
///   LANGUAGE KNOWLEDGE        → user prompt section 1 (concept menu)
///   LEARNER STATE             → user prompt section 2 (structured digest)
///   TASK                      → user prompt section 3 (the assignment)
///   OUTPUT SCHEMA             → system prompt (the JSON contract)
///
/// ...never one giant unstructured prompt. Everything here is PURE DATA
/// assembly from the trusted [PlannerContext] — no network, no Flutter,
/// no fabrication: every concept id the model may use comes from the
/// trusted graph, and the learner state comes from the M1 digest.
///
/// The AI's raw TEXT is turned into a validated plan by
/// `AiPlanParser` (spine/planner_output.dart); the model never drives
/// navigation directly (Master Brief §14/§64).
library;

import 'dart:convert';

import 'package:vaanix_app/features/learn/domain/spine/learning_plan.dart';
import 'package:vaanix_app/features/learn/domain/spine/planner.dart';

/// Human word for each activity kind, used in the prompt's activity-type
/// menu so the model sees what it may pick (mirrors [ActivityKind.label]
/// but keeps planner-specific wording stable for tests).
const Map<ActivityKind, String> kPlannerActivityDescriptions =
    <ActivityKind, String>{
  ActivityKind.newLearning: 'teach a new concept from scratch',
  ActivityKind.practice: 'more exercises on a started concept',
  ActivityKind.review: 'quick refresh of a previously learned concept',
  ActivityKind.weakRepair: 'focused repair of a struggling concept',
  ActivityKind.masteryCheck: 'check whether a concept is truly locked in',
  ActivityKind.challenge: 'a mixed challenge across learned concepts',
};

/// Builds the SYSTEM prompt: pedagogy rules + grounding rules + the JSON
/// output schema (Master Brief §62 "system/pedagogy rules" + §13 "the
/// planner MUST return structured data").
///
/// [supportedActivityTypes] is the build's real capability set — the
/// prompt only advertises kinds the app can actually execute, so the
/// validator rarely has to reject anything.
String buildPlannerSystemPrompt({
  required Set<ActivityKind> supportedActivityTypes,
  int maxActivities = 8,
}) {
  final kindMenu = <String>[
    for (final kind in ActivityKind.values)
      if (supportedActivityTypes.contains(kind))
        '- "${kind.name}" = ${kPlannerActivityDescriptions[kind]}',
  ].join('\n');

  return '''
You are the learning planner inside VaaniX, a language-learning app.
Your ONLY job is to choose the next learning steps for ONE learner.
You never chat, never answer the learner, and never do anything except
return ONE JSON object.

OUTPUT FORMAT (strict):
Return ONLY a single JSON object. No markdown, no code fences, no
commentary, no keys other than the ones below. Shape:

{
  "focusSummary": "one short friendly sentence about today's focus",
  "activities": [
    {
      "conceptId": "<id copied EXACTLY from the concept menu>",
      "activityType": "<one of the allowed activity types>",
      "difficulty": <integer 1..5>,
      "reason": "one short sentence, personal, why THIS step now",
      "estimatedMinutes": <integer 1..30>,
      "title": "optional short label; omit to use the concept title"
    }
  ]
}

GROUNDING RULES (violating any of these makes the step invalid):
1. Use ONLY conceptIds that appear in the concept menu. Never invent,
   translate, or guess ids.
2. Every activity belongs to the learner's language given in the state.
   Never mix languages.
3. difficulty is an integer 1..5 (1 = brand new, 5 = very hard).
4. estimatedMinutes values should sum to no more than the learner's
   available minutes.
5. Return at most $maxActivities activities. Fewer is fine.
6. If the learner struggles with something, repair it BEFORE teaching
   new material. If everything is strong, move forward.
7. Respect prerequisites: do not jump far ahead of what the learner
   has already practised.

ACTIVITY TYPES you may use:
$kindMenu

TONE RULES (the learner sees "reason" and "focusSummary"):
- Personal and encouraging, plain words, no linguistic jargon
  (never say "prerequisite", "schema", "CEFR", "difficulty curve").
- Speak to one learner ("you"), never about "users".
- Educational planning only. Nothing else. No harmful, unsafe, or
  off-topic content of any kind.''';
}

/// Builds the USER prompt with the three brief §62 sections:
/// LANGUAGE KNOWLEDGE, LEARNER STATE, TASK.
///
/// The concept menu is the ONLY source of usable concept ids — it is
/// rendered from the trusted graph in curriculum order, with the
/// learner's mastery status per concept so the model can decide what to
/// teach, review, skip, or repair (Master Brief §13 decision list).
String buildPlannerUserPrompt(PlannerContext context) {
  final buffer = StringBuffer();

  // ── Section 1: LANGUAGE KNOWLEDGE ──────────────────────────────────────
  buffer.writeln('=== LANGUAGE KNOWLEDGE ===');
  buffer.writeln(
      'Language: ${context.languageName} (code: ${context.languageCode}).');
  final skills = context.graph.skills;
  if (skills.isNotEmpty) {
    buffer.writeln('Topic areas, in curriculum order:');
    for (final skill in skills) {
      buffer.writeln('- ${skill.id}: ${skill.title}');
    }
  }
  buffer.writeln();
  buffer.writeln('CONCEPT MENU (the only allowed conceptIds):');
  if (context.graph.isEmpty) {
    buffer.writeln('(empty — this language has no curriculum yet)');
  } else {
    for (final concept in context.graph.concepts) {
      final stage = context.state.conceptMasteries[concept.id]?.stage;
      final status = stage == null ? 'not-started' : stage.name;
      buffer.writeln('- ${concept.id} | ${concept.title} | '
          'section ${concept.skillId} | difficulty ${concept.difficulty.name}'
          '${concept.prerequisites.isEmpty ? '' : ' | after ${concept.prerequisites.join(", ")}'}'
          ' | status: $status');
    }
  }

  // ── Section 2: LEARNER STATE ───────────────────────────────────────────
  buffer.writeln();
  buffer.writeln('=== LEARNER STATE ===');
  buffer.writeln(const JsonEncoder.withIndent('  ').convert(
    context.toStructuredDigest(),
  ));

  // ── Section 3: TASK ────────────────────────────────────────────────────
  buffer.writeln();
  buffer.writeln('=== TASK ===');
  buffer.writeln(
      'Build today\'s plan for this learner: at most 8 steps, totalling '
      'no more than ${context.minutesAvailable} minutes. '
      'Repair weak or mistaken concepts first, keep anything already '
      'strong fresh with short reviews, teach the next new concept only '
      'when the foundations are solid, and finish with a small practice '
      'or challenge step when time allows.');
  buffer.writeln('Respond with the JSON object only.');

  return buffer.toString();
}

/// Upper bound for a single raw model reply before any scanning.
///
/// M10 (Master Brief §90 "very long response"): plans and content items
/// are small, bounded outputs by contract (§63). A pathological or
/// hostile multi-megabyte reply is rejected BEFORE the balanced-brace
/// scan — the caller treats `null` exactly like any other malformed
/// output (a Left, never a hang or a crash).
const int kMaxRawModelResponseChars = 256 * 1024;

/// Extracts the first balanced top-level JSON object from raw model text.
///
/// Tolerates the common LLM wrapper failure modes without trusting them:
/// markdown code fences (```json … ```), leading/trailing prose, and
/// nested braces inside JSON strings. Returns `null` when no decodable
/// object exists — the caller treats that as a malformed planner output
/// (a Left, never a crash).
Map<String, dynamic>? extractPlanJson(String raw) {
  // M10: bound the scan before doing any work with the reply.
  if (raw.length > kMaxRawModelResponseChars) return null;

  final text = raw.trim();

  // Fast path: the whole text IS the object.
  final direct = _tryDecode(text);
  if (direct != null) return direct;

  // Fenced path: ```(json)? ... ```
  final fenceStart = text.indexOf('```');
  if (fenceStart >= 0) {
    var bodyStart = text.indexOf('\n', fenceStart);
    bodyStart = bodyStart < 0 ? fenceStart + 3 : bodyStart + 1;
    final fenceEnd = text.indexOf('```', bodyStart);
    final fenced = fenceEnd < 0 ? text.substring(bodyStart) : text.substring(
      bodyStart,
      fenceEnd,
    );
    final fromFence = _tryDecode(fenced.trim());
    if (fromFence != null) return fromFence;
  }

  // Balanced-brace scan: each '{' whose matching '}' closes a decodable
  // object. String-aware so braces inside string values never miscount.
  var searchFrom = 0;
  while (true) {
    final start = text.indexOf('{', searchFrom);
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    var closed = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        if (inString) escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          closed = true;
          final candidate = _tryDecode(text.substring(start, i + 1));
          if (candidate != null) return candidate;
          // Not decodable — resume the scan after this object.
          searchFrom = i + 1;
          break;
        }
      }
    }
    if (!closed) return null; // unbalanced object — nothing decodable
  }
}

Map<String, dynamic>? _tryDecode(String candidate) {
  if (candidate.isEmpty) return null;
  try {
    final decoded = jsonDecode(candidate);
    if (decoded is Map<String, dynamic>) return decoded;
    // jsonDecode yields Map<String, dynamic> for objects; anything else
    // (list, string, number) is not a plan.
    return null;
  } on FormatException {
    return null;
  } catch (_) {
    return null;
  }
}
