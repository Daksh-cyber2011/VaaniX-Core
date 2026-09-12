/// Exam Mode 2.0 — Syllabus layer barrel (M1).
///
/// Layer 1 (official syllabus authority) public surface:
///  * [CourseSyllabus], [SyllabusTrackId], [BoardId] — domain models
///  * [SyllabusIndex] — course catalog
///  * [SyllabusRepository], providers — asset loading
library;

export 'package:vaanix_app/features/exam/data/syllabus/syllabus_index.dart';
export 'package:vaanix_app/features/exam/data/syllabus/syllabus_loader.dart';
export 'package:vaanix_app/features/exam/data/syllabus/syllabus_models.dart';
