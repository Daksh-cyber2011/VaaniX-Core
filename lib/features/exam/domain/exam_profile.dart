/// Exam Mode 2.0 — Exam Profile Domain (M3, master plan §8–§9, §12)
///
/// The student's EXAM PROFILE: when they want to be exam-ready, how much
/// time they can actually study, and how sessions should feel. This sits
/// ON TOP of the confirmed exam scope (M2) and FEEDS the diagnostic (M4)
/// and the personalized planner (M5).
///
/// Rules encoded here (§8 READINESS TARGET):
///  * The PRIMARY question is "by when do you want to be exam-ready?",
///    NOT "when is your exam". The student may provide a target DATE
///    (option A), a DURATION in weeks (option B), or both (option C).
///    When both are provided the TARGET DATE is the primary planning
///    anchor and the duration is derived information.
///  * The actual exam date may be stored OPTIONALLY when known, but it
///    must never be the only planning mechanism.
///  * At least ONE readiness source (date or duration) is required — a
///    profile without an anchor is invalid and never persisted.
///
/// Rules encoded here (§9 AVAILABLE STUDY TIME):
///  * available ≠ recommended. The student states what they can
///    REALISTICALLY give; the planner must fit inside it. 5 min/day is
///    as legitimate as 2 h/day.
///  * Boundaries are generous but bounded, so corrupt storage can never
///    fabricate a 0-minute or 24-hour study day.
///
/// Migration safety (§57 DATA MIGRATION):
///  * `schemaVersion` on the JSON; unknown versions deserialize with
///    per-field fallbacks instead of throwing; unknown enum values
///    degrade to defaults; the loader never destroys sibling data.
///  * All DateTime round-trips go through `DateTime.tryParse` — a bad
///    date degrades to `null`, never to a crash.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

/// How the student wants sessions paced (§12 student preferences).
enum StudyPace { balanced, intensive, light }

StudyPace _paceFromName(String? name) => switch (name) {
      'intensive' => StudyPace.intensive,
      'light' => StudyPace.light,
      _ => StudyPace.balanced,
    };

/// The persisted exam profile for one track (§12).
class ExamProfile extends Equatable {
  const ExamProfile({
    required this.trackId,
    required this.dailyStudyMinutes,
    required this.studyDaysPerWeek,
    this.readinessTargetDate,
    this.readinessDurationWeeks,
    this.actualExamDate,
    this.pace = StudyPace.balanced,
    this.updatedAtIso = '',
    this.schemaVersion = currentSchemaVersion,
  });

  /// Bump when the persisted shape changes; add a migration branch in
  /// [fromJson] (older versions keep loading — never a crash, §57).
  static const int currentSchemaVersion = 1;

  /// Minimum plausible daily study time (§9: never punish small budgets).
  static const int minDailyMinutes = 5;

  /// Maximum plausible daily study time (a full generous day).
  static const int maxDailyMinutes = 480;

  /// Duration-weeks bounds (§8: "ready in 8 weeks" style anchors).
  static const int minDurationWeeks = 1;
  static const int maxDurationWeeks = 52;

  static const int minStudyDaysPerWeek = 1;
  static const int maxStudyDaysPerWeek = 7;

  /// Track this profile belongs to (course isolation, §38).
  final String trackId;

  /// What the student can REALISTICALLY study per study day (§9).
  final int dailyStudyMinutes;

  /// How many days per week the student studies.
  final int studyDaysPerWeek;

  /// Option A — "I want to be exam-ready by <date>" (primary anchor).
  final DateTime? readinessTargetDate;

  /// Option B — "I want to be ready in N weeks".
  final int? readinessDurationWeeks;

  /// OPTIONAL actual exam date when known (§8). Never the only anchor.
  final DateTime? actualExamDate;

  /// Session pacing preference (§12 student preferences).
  final StudyPace pace;

  final String updatedAtIso;
  final int schemaVersion;

  /// True when at least one readiness source exists (A, B or C).
  bool get hasReadinessSource =>
      readinessTargetDate != null || readinessDurationWeeks != null;

  /// The planning anchor (§8): target DATE wins when both are provided;
  /// otherwise the duration-derived date; null when neither exists
  /// (invalid profile — [validate] rejects it).
  DateTime? readinessAnchor(DateTime now) {
    final target = readinessTargetDate;
    if (target != null) return target;
    final weeks = readinessDurationWeeks;
    if (weeks == null) return null;
    return now.add(Duration(days: 7 * weeks));
  }

  /// Weeks between [now] and the anchor, when computable. Used by the
  /// M5 planner to pace the syllabus across the window.
  int? weeksToAnchor(DateTime now) {
    final anchor = readinessAnchor(now);
    if (anchor == null) return null;
    final days = anchor.difference(now).inDays;
    if (days < 0) return 0; // anchor in the past → window closed
    return (days / 7).ceil();
  }

  /// Weekly study budget = daily minutes × study days.
  int get weeklyStudyMinutes => dailyStudyMinutes * studyDaysPerWeek;

  /// A short, honest human sentence about the budget (student-facing
  /// language is qualitative — never a scary number dashboard, §30).
  String budgetSentence() {
    final hours = dailyStudyMinutes / 60;
    final perDay = hours >= 1
        ? '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} घंटे'
        : '$dailyStudyMinutes मिनट';
    return 'प्रति दिन $perDay · हफ़्ते में $studyDaysPerWeek दिन';
  }

  /// Domain validation. Returns a list of violations (empty = valid).
  /// Corrupt/absent storage can never produce a silently-valid profile:
  /// invalid data is surfaced, not absorbed.
  List<String> validate({DateTime? now}) {
    final errors = <String>[];
    final today = now ?? DateTime.now();

    if (dailyStudyMinutes < minDailyMinutes ||
        dailyStudyMinutes > maxDailyMinutes) {
      errors.add('dailyStudyMinutes must be $minDailyMinutes..'
          '$maxDailyMinutes (got $dailyStudyMinutes)');
    }
    if (studyDaysPerWeek < minStudyDaysPerWeek ||
        studyDaysPerWeek > maxStudyDaysPerWeek) {
      errors.add('studyDaysPerWeek must be '
          '$minStudyDaysPerWeek..$maxStudyDaysPerWeek (got $studyDaysPerWeek)');
    }
    if (!hasReadinessSource) {
      errors.add('A readiness target (date or duration) is required (§8)');
    }
    if (readinessDurationWeeks != null &&
        (readinessDurationWeeks! < minDurationWeeks ||
            readinessDurationWeeks! > maxDurationWeeks)) {
      errors.add('readinessDurationWeeks must be $minDurationWeeks..'
          '$maxDurationWeeks (got $readinessDurationWeeks)');
    }
    // Dates may be today (a same-day readiness target is odd but legal);
    // strictly past dates are rejected so a stale profile cannot anchor
    // planning into the past.
    for (final field in [
      ('readinessTargetDate', readinessTargetDate),
      ('actualExamDate', actualExamDate),
    ]) {
      final d = field.$2;
      if (d != null &&
          d.isBefore(DateTime(today.year, today.month, today.day))) {
        errors.add('${field.$1} is in the past (${d.toIso8601String()})');
      }
    }
    // Actual exam date, when present, must not predate the readiness
    // target — being "ready" after the exam is a data-entry error.
    if (actualExamDate != null && readinessTargetDate != null) {
      if (actualExamDate!.isBefore(DateTime(readinessTargetDate!.year,
          readinessTargetDate!.month, readinessTargetDate!.day))) {
        errors.add('actualExamDate precedes readinessTargetDate');
      }
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;

  ExamProfile copyWith({
    int? dailyStudyMinutes,
    int? studyDaysPerWeek,
    DateTime? readinessTargetDate,
    bool clearReadinessTargetDate = false,
    int? readinessDurationWeeks,
    bool clearReadinessDurationWeeks = false,
    DateTime? actualExamDate,
    bool clearActualExamDate = false,
    StudyPace? pace,
    String? updatedAtIso,
  }) =>
      ExamProfile(
        trackId: trackId,
        dailyStudyMinutes: dailyStudyMinutes ?? this.dailyStudyMinutes,
        studyDaysPerWeek: studyDaysPerWeek ?? this.studyDaysPerWeek,
        readinessTargetDate: clearReadinessTargetDate
            ? null
            : (readinessTargetDate ?? this.readinessTargetDate),
        readinessDurationWeeks: clearReadinessDurationWeeks
            ? null
            : (readinessDurationWeeks ?? this.readinessDurationWeeks),
        actualExamDate: clearActualExamDate
            ? null
            : (actualExamDate ?? this.actualExamDate),
        pace: pace ?? this.pace,
        updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      );

  /// Defensive deserialization (§57): unknown fields ignored, bad values
  /// degrade to defaults, bad dates degrade to null. NEVER throws.
  factory ExamProfile.fromJson(Map<String, dynamic> json) {
    final trackId = json['trackId'] as String? ?? '';
    final minutes = (json['dailyStudyMinutes'] as num?)?.toInt() ?? 30;
    final days = (json['studyDaysPerWeek'] as num?)?.toInt() ?? 5;
    final weeks = (json['readinessDurationWeeks'] as num?)?.toInt();
    return ExamProfile(
      trackId: trackId,
      dailyStudyMinutes: minutes < minDailyMinutes ? minDailyMinutes : minutes,
      studyDaysPerWeek: days < minStudyDaysPerWeek ? minStudyDaysPerWeek : days,
      readinessTargetDate: _parseDate(json['readinessTargetDate']),
      readinessDurationWeeks: (weeks == null || weeks < minDurationWeeks)
          ? null
          : (weeks > maxDurationWeeks ? maxDurationWeeks : weeks),
      actualExamDate: _parseDate(json['actualExamDate']),
      pace: _paceFromName(json['pace'] as String?),
      updatedAtIso: json['updatedAtIso'] as String? ?? '',
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw as String);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'trackId': trackId,
        'dailyStudyMinutes': dailyStudyMinutes,
        'studyDaysPerWeek': studyDaysPerWeek,
        if (readinessTargetDate != null)
          'readinessTargetDate': readinessTargetDate!.toIso8601String(),
        if (readinessDurationWeeks != null)
          'readinessDurationWeeks': readinessDurationWeeks,
        if (actualExamDate != null)
          'actualExamDate': actualExamDate!.toIso8601String(),
        'pace': pace.name,
        'updatedAtIso': updatedAtIso,
      };

  @override
  List<Object?> get props => [
        trackId,
        dailyStudyMinutes,
        studyDaysPerWeek,
        readinessTargetDate,
        readinessDurationWeeks,
        actualExamDate,
        pace,
      ];
}
