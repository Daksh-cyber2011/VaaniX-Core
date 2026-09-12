/// Exam Mode 2.0 — Syllabus Catalog Index (M1)
///
/// Typed projection of `assets/syllabus/<board>/index.json`: the
/// board → class → subject → course navigation tree. The catalog exists so
/// the M2 selection UI can be built entirely from Layer-1 official data
/// without loading every course file.
///
/// Pure Dart — no Flutter imports.
library;

import 'package:equatable/equatable.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';

/// One course entry in the catalog (points at a canonical course file).
class SyllabusCourseEntry extends Equatable {
  const SyllabusCourseEntry({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.file,
    required this.literatureStatus,
    this.subjectCode,
  });

  factory SyllabusCourseEntry.fromJson(Map<String, dynamic> json) =>
      SyllabusCourseEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        nameEn: (json['nameEn'] as String?) ?? '',
        file: json['file'] as String,
        literatureStatus: SyllabusItemStatus.fromName(
            json['literatureStatus'] as String?),
        subjectCode: json['subjectCode'] as String?,
      );

  final String id;
  final String name;
  final String nameEn;

  /// Course file name relative to the board directory.
  final String file;

  /// Whether literature chapters are published for this course yet.
  final SyllabusItemStatus literatureStatus;
  final String? subjectCode;

  bool get literaturePending =>
      literatureStatus == SyllabusItemStatus.pendingOfficialAnnouncement;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameEn': nameEn,
        'file': file,
        'literatureStatus': literatureStatus.name,
        if (subjectCode != null) 'subjectCode': subjectCode,
      };

  @override
  List<Object?> get props => [id, file];
}

/// One subject (with its course variants) inside a class.
class SyllabusSubjectEntry extends Equatable {
  const SyllabusSubjectEntry({
    required this.id,
    required this.name,
    required this.courses,
  });

  factory SyllabusSubjectEntry.fromJson(Map<String, dynamic> json) =>
      SyllabusSubjectEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        courses: (json['courses'] as List<dynamic>)
            .map((e) =>
                SyllabusCourseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final List<SyllabusCourseEntry> courses;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, courses];
}

/// One class (grade) with its subjects.
class SyllabusClassEntry extends Equatable {
  const SyllabusClassEntry({required this.klass, required this.subjects});

  factory SyllabusClassEntry.fromJson(Map<String, dynamic> json) =>
      SyllabusClassEntry(
        klass: (json['class'] as num).toInt(),
        subjects: (json['subjects'] as List<dynamic>)
            .map(
                (e) => SyllabusSubjectEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int klass;
  final List<SyllabusSubjectEntry> subjects;

  Map<String, dynamic> toJson() => {
        'class': klass,
        'subjects': subjects.map((s) => s.toJson()).toList(),
      };

  @override
  List<Object?> get props => [klass, subjects];
}

/// The whole catalog: board + version + class tree.
class SyllabusIndex extends Equatable {
  const SyllabusIndex({
    required this.board,
    required this.syllabusVersion,
    required this.classes,
  });

  factory SyllabusIndex.fromJson(Map<String, dynamic> json) {
    final board =
        (json['board'] as Map<String, dynamic>).cast<String, dynamic>();
    return SyllabusIndex(
      board: BoardId(board['id'] as String),
      syllabusVersion: json['syllabusVersion'] as String,
      classes: (json['classes'] as List<dynamic>)
          .map((e) => SyllabusClassEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final BoardId board;
  final String syllabusVersion;
  final List<SyllabusClassEntry> classes;

  /// All course entries across the catalog.
  List<SyllabusCourseEntry> get allCourses => classes
      .expand((c) => c.subjects)
      .expand((s) => s.courses)
      .toList();

  /// Look up a course entry by track id.
  SyllabusCourseEntry? courseById(String trackId) {
    for (final c in allCourses) {
      if (c.id == trackId) return c;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'board': {'id': board.value},
        'syllabusVersion': syllabusVersion,
        'classes': classes.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [board.value, syllabusVersion, classes];
}
