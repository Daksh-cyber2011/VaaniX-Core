/// Exam Mode 2.0 — Canonical Syllabus Domain Models (M1)
///
/// Layer 1 of the Exam Mode content hierarchy: the OFFICIAL syllabus
/// authority. These models are a strict, typed projection of the canonical
/// JSON shipped under `assets/syllabus/<board>/` (generated from the
/// official CBSE 2026-27 curriculum documents — see
/// `docs/Syllabus/INGESTION_REPORT.md`).
///
/// Design rules (master plan §3, §38, §39, §60):
///  * Board-agnostic: [BoardId] + [SyllabusTrackId] value types; CBSE is
///    DATA, never code. A future ICSE drop adds assets, not engine changes.
///  * Stable IDs everywhere. Display titles are never identifiers.
///  * Course isolation is structural: every [SyllabusItem] knows its track,
///    so content layers can never mix tracks (Hindi A vs Hindi B, Sanskrit
///    vs Sanskrit Communicative, Class 9 vs 10).
///  * `pendingOfficialAnnouncement` is a first-class status: the official
///    Class 9 2026-27 documents have NOT yet published literature chapter
///    lists. Such items exist structurally but MUST be rendered as
///    "awaiting official chapter list" — never fabricated.
///  * `ocrUncertain` marks items whose source glyph could not be
///    machine-verified with full confidence (flagged, never guessed).
///  * Assessment classification: `board` vs `internal` (Class 10 board-exam
///    preparation must prioritize board scope — master plan §7).
///
/// Pure Dart — no Flutter imports — so the whole layer is unit-testable.
library;

import 'package:equatable/equatable.dart';

/// Closed schema constants of the canonical syllabus JSON (generator
/// contract — see tools/syllabus/generate_syllabus.py).
class SyllabusSchema {
  const SyllabusSchema._();

  /// Every section `stableKey` the canonical generator can emit. Used as
  /// a structural guard: a unit id `<track>_<segment>_…` belongs to
  /// `<track>` only when `<segment>` is one of these (or the chapter
  /// prefix `ch`), which seals the course-isolation boundary even when
  /// one track id is a prefix of another (cbse_10_sanskrit vs
  /// cbse_10_sanskrit_communicative).
  static const Set<String> knownSectionStableKeys = {
    'unread',
    'grammar',
    'literature',
    'writing',
  };

  /// Prefix of chapter unit ids inside prescribed books.
  static const String chapterIdSegment = 'ch';
}

/// A board identity (CBSE today; ICSE later without engine changes).
class BoardId extends Equatable {
  const BoardId(this.value);

  /// Canonical board key, e.g. `cbse`.
  final String value;

  /// The currently supported board (V1).
  static const BoardId cbse = BoardId('cbse');

  bool get isSupported => value == 'cbse' || value == 'icse';

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'BoardId($value)';
}

/// A full course identity: board + class + subject + course variant.
///
/// This is the atomic unit of course isolation. Two tracks (e.g. Hindi A and
/// Hindi B) never share a [SyllabusTrackId].
class SyllabusTrackId extends Equatable {
  const SyllabusTrackId({
    required this.board,
    required this.klass,
    required this.subjectId,
    required this.courseId,
  });

  factory SyllabusTrackId.parse(String id) {
    // cbse_10_hindi_a -> board=cbse, class=10, subject=hindi, course=a
    // cbse_9_sanskrit -> course segment omitted (single-course subject).
    final parts = id.split('_');
    if (parts.length < 3 || parts[0].isEmpty) {
      throw FormatException('Invalid SyllabusTrackId: $id');
    }
    final klass = int.tryParse(parts[1]);
    if (klass == null) {
      throw FormatException('Invalid class segment in SyllabusTrackId: $id');
    }
    return SyllabusTrackId(
      board: BoardId(parts[0]),
      klass: klass,
      subjectId: parts[2],
      courseId: parts.length > 3 ? parts.sublist(3).join('_') : '',
    );
  }

  final BoardId board;
  final int klass;
  final String subjectId;
  final String courseId;

  /// Full stable identifier, e.g. `cbse_10_sanskrit_communicative`.
  /// Single-course subjects omit the course segment: `cbse_9_sanskrit`.
  String get value => courseId.isEmpty
      ? '${board.value}_${klass}_$subjectId'
      : '${board.value}_${klass}_$subjectId\_$courseId';

  /// Asset path of this course's canonical file.
  String get assetPath => 'assets/syllabus/${board.value}/$value.json';

  bool sameSubject(SyllabusTrackId other) =>
      board == other.board &&
      klass == other.klass &&
      subjectId == other.subjectId;

  @override
  List<Object?> get props => [board.value, klass, subjectId, courseId];

  @override
  String toString() => 'SyllabusTrackId($value)';
}

/// Publication status of a syllabus item.
enum SyllabusItemStatus {
  /// Officially published and exam-relevant.
  published,

  /// The official document has not published this content yet (Class 9
  /// literature chapter lists for 2026-27). Never fabricate content here.
  pendingOfficialAnnouncement;

  static SyllabusItemStatus fromName(String? name) {
    switch (name) {
      case 'pendingOfficialAnnouncement':
        return SyllabusItemStatus.pendingOfficialAnnouncement;
      default:
        return SyllabusItemStatus.published;
    }
  }
}

/// Whether a scope unit belongs to the board examination or internal
/// assessment. Class 10 planning must prioritize board scope (§7).
enum AssessmentType { board, internal }

AssessmentType _assessmentType(String? name) =>
    name == 'internal' ? AssessmentType.internal : AssessmentType.board;

/// Question pattern attached to an item, e.g. `1×3 MCQ` or `2×2`.
class QuestionPattern extends Equatable {
  const QuestionPattern({
    required this.pattern,
    this.marksEach,
    this.count,
    this.totalMarks,
  });

  factory QuestionPattern.fromJson(Map<String, dynamic> json) =>
      QuestionPattern(
        pattern: json['pattern'] as String,
        marksEach: (json['marksEach'] as num?)?.toDouble(),
        count: (json['count'] as num?)?.toInt(),
        totalMarks: (json['totalMarks'] as num?)?.toDouble(),
      );

  /// Human-readable official pattern, e.g. `बहुविकल्पीय (MCQ) 1×3`.
  final String pattern;

  /// Marks per question (0.5 supported for half-mark items).
  final double? marksEach;
  final int? count;
  final double? totalMarks;

  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        if (marksEach != null) 'marksEach': marksEach,
        if (count != null) 'count': count,
        if (totalMarks != null) 'totalMarks': totalMarks,
      };

  @override
  List<Object?> get props => [pattern, marksEach, count, totalMarks];
}

/// The smallest selectable scope unit (master plan §5): a topic, a writing
/// task, a comprehension block, or (for Class 10 Sanskrit books) a chapter.
class SyllabusItem extends Equatable {
  const SyllabusItem({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.sectionId,
    required this.assessmentType,
    required this.status,
    this.marks,
    this.questionPatterns = const [],
    this.details,
    this.ocrUncertain = false,
    this.note,
    this.sourceRef,
    this.contentTags = const [],
  });

  factory SyllabusItem.fromJson(Map<String, dynamic> json) => SyllabusItem(
        id: json['id'] as String,
        title: json['title'] as String,
        titleEn: (json['titleEn'] as String?) ?? '',
        sectionId: json['sectionId'] as String,
        marks: (json['marks'] as num?)?.toDouble(),
        assessmentType: _assessmentType(json['assessmentType'] as String?),
        status: SyllabusItemStatus.fromName(json['status'] as String?),
        questionPatterns: (json['questionPatterns'] as List<dynamic>? ?? [])
            .map((e) => QuestionPattern.fromJson(e as Map<String, dynamic>))
            .toList(),
        details:
            (json['details'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
        ocrUncertain: json['ocrUncertain'] as bool? ?? false,
        note: json['note'] as String?,
        sourceRef: json['sourceRef'] == null
            ? null
            : SourceReference.fromJson(
                (json['sourceRef'] as Map<String, dynamic>)
                    .cast<String, dynamic>()),
        contentTags: (json['contentTags'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );

  /// Stable ID, e.g. `cbse_10_sanskrit_grammar_sandhi`.
  final String id;

  /// Official Devanagari display title.
  final String title;

  /// English display title (for accessibility / bilingual UI).
  final String titleEn;

  final String sectionId;
  final double? marks;
  final AssessmentType assessmentType;
  final SyllabusItemStatus status;

  /// Official question patterns with mark arithmetic.
  final List<QuestionPattern> questionPatterns;

  /// Official sub-topics (e.g. सन्धि sub-types) — display/grounding data.
  final Map<String, dynamic>? details;

  /// True when the source glyph needed OCR verification and could not be
  /// confirmed with full confidence. Surfaced, never silently resolved.
  final bool ocrUncertain;
  final String? note;

  final SourceReference? sourceRef;
  final List<String> contentTags;

  bool get isPending =>
      status == SyllabusItemStatus.pendingOfficialAnnouncement;

  /// Selectable as exam scope only when officially published.
  bool get isSelectable => status == SyllabusItemStatus.published;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'titleEn': titleEn,
        'sectionId': sectionId,
        if (marks != null) 'marks': marks,
        'assessmentType': assessmentType.name,
        'status': status.name,
        'questionPatterns': questionPatterns.map((p) => p.toJson()).toList(),
        if (details != null) 'details': details,
        if (ocrUncertain) 'ocrUncertain': true,
        if (note != null) 'note': note,
        if (sourceRef != null) 'sourceRef': sourceRef!.toJson(),
        if (contentTags.isNotEmpty) 'contentTags': contentTags,
      };

  @override
  List<Object?> get props => [id, title, marks, status, assessmentType];
}

/// A chapter of a prescribed book.
///
/// This supports a book's official contents without copying its copyrighted
/// prose into the app. A chapter can therefore be used as the stable scope
/// boundary for diagnostics, plans, practice, mocks and progress.
class SyllabusChapter extends Equatable {
  const SyllabusChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.type,
    this.author,
    this.sourceFile,
    this.examRelevance,
    this.ocrUncertain = false,
  });

  factory SyllabusChapter.fromJson(Map<String, dynamic> json) =>
      SyllabusChapter(
        id: json['id'] as String,
        number: (json['number'] as num).toInt(),
        title: json['title'] as String,
        type: json['type'] as String? ?? 'prose',
        author: json['author'] as String?,
        sourceFile: json['sourceFile'] as String?,
        examRelevance: json['examRelevance'] as String?,
        ocrUncertain: json['ocrUncertain'] as bool? ?? false,
      );

  final String id;
  final int number;
  final String title;

  /// `prose` | `poetry` (informational).
  final String type;

  /// Official author/poet credit where the prescribed book identifies one.
  /// It is display and AI-grounding metadata, never a content substitute.
  final String? author;

  /// File name in the verified supplied NCERT package, when available.
  final String? sourceFile;

  /// Chapters can be `internal-only` (Sanskrit Communicative ch. 10 & 11).
  final String? examRelevance;
  final bool ocrUncertain;

  bool get isInternalOnly => examRelevance == 'internal-only';

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'title': title,
        'type': type,
        if (author != null) 'author': author,
        if (sourceFile != null) 'sourceFile': sourceFile,
        if (examRelevance != null) 'examRelevance': examRelevance,
        if (ocrUncertain) 'ocrUncertain': true,
      };

  @override
  List<Object?> get props => [id, number, title];
}

/// A prescribed book with optional chapter list.
class PrescribedBook extends Equatable {
  const PrescribedBook({
    required this.id,
    required this.title,
    required this.publisher,
    required this.status,
    this.chapters = const [],
    this.note,
  });

  factory PrescribedBook.fromJson(Map<String, dynamic> json) => PrescribedBook(
        id: json['id'] as String,
        title: json['title'] as String,
        publisher: json['publisher'] as String? ?? '',
        status: SyllabusItemStatus.fromName(json['status'] as String?),
        chapters: (json['chapters'] as List<dynamic>? ?? [])
            .map((e) => SyllabusChapter.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String?,
      );

  final String id;
  final String title;
  final String publisher;
  final SyllabusItemStatus status;
  final List<SyllabusChapter> chapters;
  final String? note;

  bool get isPending =>
      status == SyllabusItemStatus.pendingOfficialAnnouncement;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'publisher': publisher,
        'status': status.name,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        if (note != null) 'note': note,
      };

  @override
  List<Object?> get props => [id, title, status];
}

/// A major exam section (खंड/भाग), e.g. अपठित बोध (14 marks).
class SyllabusSection extends Equatable {
  const SyllabusSection({
    required this.id,
    required this.stableKey,
    required this.title,
    required this.titleEn,
    required this.marks,
    required this.assessmentType,
    this.items = const [],
    this.note,
  });

  factory SyllabusSection.fromJson(Map<String, dynamic> json) =>
      SyllabusSection(
        id: json['id'] as String,
        stableKey: json['stableKey'] as String,
        title: json['title'] as String,
        titleEn: (json['titleEn'] as String?) ?? '',
        marks: (json['marks'] as num).toDouble(),
        assessmentType: _assessmentType(json['assessmentType'] as String?),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => SyllabusItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String?,
      );

  final String id;
  final String stableKey;
  final String title;
  final String titleEn;
  final double marks;
  final AssessmentType assessmentType;
  final List<SyllabusItem> items;
  final String? note;

  /// Published, selectable items only.
  List<SyllabusItem> get selectableItems =>
      items.where((i) => i.isSelectable).toList();

  /// Pending items (Class 9 literature) — rendered as awaiting announcement.
  List<SyllabusItem> get pendingItems =>
      items.where((i) => i.isPending).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'stableKey': stableKey,
        'title': title,
        'titleEn': titleEn,
        'marks': marks,
        'assessmentType': assessmentType.name,
        'items': items.map((i) => i.toJson()).toList(),
        if (note != null) 'note': note,
      };

  @override
  List<Object?> get props => [id, marks, assessmentType];
}

/// Reference back to the official PDF page(s) an item came from.
class SourceReference extends Equatable {
  const SourceReference({required this.pdf, required this.pages});

  factory SourceReference.fromJson(Map<String, dynamic> json) =>
      SourceReference(
        pdf: json['pdf'] as String,
        pages: (json['pages'] as List<dynamic>).map((e) => e as int).toList(),
      );

  final String pdf;
  final List<int> pages;

  Map<String, dynamic> toJson() => {'pdf': pdf, 'pages': pages};

  @override
  List<Object?> get props => [pdf, pages];
}

/// An internal-assessment component (e.g. सामयिक आकलन, 5 marks).
class InternalAssessmentComponent extends Equatable {
  const InternalAssessmentComponent({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.marks,
  });

  factory InternalAssessmentComponent.fromJson(Map<String, dynamic> json) =>
      InternalAssessmentComponent(
        id: json['id'] as String,
        title: json['title'] as String,
        titleEn: (json['titleEn'] as String?) ?? '',
        marks: (json['marks'] as num).toDouble(),
      );

  final String id;
  final String title;
  final String titleEn;
  final double marks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'titleEn': titleEn,
        'marks': marks,
      };

  @override
  List<Object?> get props => [id, marks];
}

/// An announcement the official PDF itself makes about unpublished content.
class PendingAnnouncement extends Equatable {
  const PendingAnnouncement({
    required this.appliesTo,
    required this.reason,
    required this.sourceQuote,
    required this.sourcePages,
    required this.action,
  });

  factory PendingAnnouncement.fromJson(Map<String, dynamic> json) =>
      PendingAnnouncement(
        appliesTo: json['appliesTo'] as String,
        reason: json['reason'] as String,
        sourceQuote: json['sourceQuote'] as String,
        sourcePages: (json['sourcePages'] as List<dynamic>)
            .map((e) => e as int)
            .toList(),
        action: json['action'] as String,
      );

  final String appliesTo;
  final String reason;
  final String sourceQuote;
  final List<int> sourcePages;
  final String action;

  Map<String, dynamic> toJson() => {
        'appliesTo': appliesTo,
        'reason': reason,
        'sourceQuote': sourceQuote,
        'sourcePages': sourcePages,
        'action': action,
      };

  @override
  List<Object?> get props => [appliesTo, reason];
}

/// The complete canonical syllabus for one course.
class CourseSyllabus extends Equatable {
  const CourseSyllabus({
    required this.id,
    required this.board,
    required this.klass,
    required this.subjectId,
    required this.subjectName,
    required this.courseName,
    required this.courseNameEn,
    required this.subjectCode,
    required this.syllabusVersion,
    required this.sourcePdf,
    required this.boardExamTotalMarks,
    required this.boardExamDurationHours,
    required this.internalAssessmentMarks,
    required this.internalComponents,
    required this.sections,
    required this.books,
    required this.notes,
    this.pending,
  });

  factory CourseSyllabus.fromJson(Map<String, dynamic> json) {
    final course =
        (json['course'] as Map<String, dynamic>).cast<String, dynamic>();
    final subject =
        (json['subject'] as Map<String, dynamic>).cast<String, dynamic>();
    final assessment =
        (json['assessment'] as Map<String, dynamic>).cast<String, dynamic>();
    final boardExam = (assessment['boardExam'] as Map<String, dynamic>)
        .cast<String, dynamic>();
    final internal = (assessment['internalAssessment'] as Map<String, dynamic>)
        .cast<String, dynamic>();
    final source =
        (json['source'] as Map<String, dynamic>).cast<String, dynamic>();
    final trackId = SyllabusTrackId.parse(json['id'] as String);

    return CourseSyllabus(
      id: trackId,
      board: BoardId((json['board'] as Map<String, dynamic>)['id'] as String),
      klass: (json['class'] as num).toInt(),
      subjectId: subject['id'] as String,
      subjectName: subject['name'] as String,
      courseName: course['name'] as String,
      courseNameEn: (course['nameEn'] as String?) ?? '',
      subjectCode: course['subjectCode'] as String?,
      syllabusVersion: json['syllabusVersion'] as String,
      sourcePdf: source['pdf'] as String,
      boardExamTotalMarks: (boardExam['totalMarks'] as num).toDouble(),
      boardExamDurationHours: (boardExam['durationHours'] as num).toDouble(),
      internalAssessmentMarks: (internal['totalMarks'] as num).toDouble(),
      internalComponents: (internal['components'] as List<dynamic>? ?? [])
          .map((e) =>
              InternalAssessmentComponent.fromJson(e as Map<String, dynamic>))
          .toList(),
      sections: (json['sections'] as List<dynamic>)
          .map((e) => SyllabusSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      books: (json['prescribedBooks'] as List<dynamic>? ?? [])
          .map((e) => PrescribedBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      pending: json['pendingOfficialAnnouncement'] == null
          ? null
          : PendingAnnouncement.fromJson(
              (json['pendingOfficialAnnouncement'] as Map<String, dynamic>)
                  .cast<String, dynamic>()),
    );
  }

  final SyllabusTrackId id;
  final BoardId board;
  final int klass;
  final String subjectId;
  final String subjectName;
  final String courseName;
  final String courseNameEn;
  final String? subjectCode;
  final String syllabusVersion;
  final String sourcePdf;

  final double boardExamTotalMarks;
  final double boardExamDurationHours;
  final double internalAssessmentMarks;
  final List<InternalAssessmentComponent> internalComponents;

  final List<SyllabusSection> sections;
  final List<PrescribedBook> books;
  final List<String> notes;
  final PendingAnnouncement? pending;

  /// Board-exam sections only (Class 10 planning priority — §7).
  List<SyllabusSection> get boardSections =>
      sections.where((s) => s.assessmentType == AssessmentType.board).toList();

  /// Sum of board-section marks; must equal [boardExamTotalMarks].
  double get computedBoardMarks =>
      boardSections.fold(0.0, (sum, s) => sum + s.marks);

  /// True when literature chapters await the official announcement.
  bool get hasPendingLiterature =>
      pending != null ||
      sections.any((s) => s.items.any((i) => i.isPending)) ||
      books.any((b) => b.isPending);

  /// Flat view of all published items (for scope selection, M2).
  List<SyllabusItem> get allItems => sections.expand((s) => s.items).toList();

  /// All chapters across prescribed books (Class 10 Sanskrit tracks).
  List<SyllabusChapter> get allChapters =>
      books.expand((b) => b.chapters).toList();

  /// Items flagged for human OCR verification.
  List<SyllabusItem> get uncertainItems =>
      allItems.where((i) => i.ocrUncertain).toList();

  /// Validation: board sections must sum to the official board total and
  /// every section's items must sum to the section marks.
  List<String> validate() {
    final errors = <String>[];
    if (computedBoardMarks != boardExamTotalMarks) {
      errors.add(
          'board sections sum $computedBoardMarks != $boardExamTotalMarks');
    }
    for (final s in sections) {
      final withMarks = s.items.where((i) => i.marks != null).toList();
      if (withMarks.isNotEmpty) {
        final total = withMarks.fold(0.0, (sum, i) => sum + i.marks!);
        if (total != s.marks) {
          errors.add('${s.id}: items sum $total != ${s.marks}');
        }
      }
    }
    if (internalComponents.isNotEmpty) {
      final csum = internalComponents.fold(0.0, (sum, c) => sum + c.marks);
      if (csum != internalAssessmentMarks) {
        errors.add('internal components sum $csum != $internalAssessmentMarks');
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'board': {'id': board.value},
        'class': klass,
        'subject': {'id': subjectId, 'name': subjectName},
        'course': {
          'id': id.value,
          'name': courseName,
          'nameEn': courseNameEn,
          if (subjectCode != null) 'subjectCode': subjectCode,
        },
        'syllabusVersion': syllabusVersion,
        'source': {'pdf': sourcePdf},
        'assessment': {
          'boardExam': {
            'totalMarks': boardExamTotalMarks,
            'durationHours': boardExamDurationHours,
          },
          'internalAssessment': {
            'totalMarks': internalAssessmentMarks,
            'components': internalComponents.map((c) => c.toJson()).toList(),
          },
        },
        'sections': sections.map((s) => s.toJson()).toList(),
        'prescribedBooks': books.map((b) => b.toJson()).toList(),
        'notes': notes,
        if (pending != null) 'pendingOfficialAnnouncement': pending!.toJson(),
      };

  @override
  List<Object?> get props => [id.value, syllabusVersion];
}
