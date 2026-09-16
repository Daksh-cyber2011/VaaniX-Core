/// Exam Mode 2.0 — M1 Syllabus Catalog & Loader Tests
///
/// Tests the index/catalog contract and the asset loader (with a mocked
/// asset bundle, following the project's `TestWidgetsFlutterBinding`
/// conventions).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Loads the real assets through a mocked asset-bundle channel so the
  /// loader is exercised end-to-end exactly as in the app.
  void mockRealAssets() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final path = utf8.decode(message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      if (bytes.isEmpty) return null;
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    });
  }

  void clearMock() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('assets/syllabus/cbse/cbse_10_sanskrit.json');
    rootBundle.evict('assets/syllabus/cbse/index.json');
  }

  void mockMissingAssets() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => null);
    rootBundle.evict('assets/syllabus/cbse/cbse_10_sanskrit.json');
    rootBundle.evict('assets/syllabus/cbse/index.json');
  }

  group('catalog index (assets/syllabus/cbse/index.json)', () {
    test('parses into 2 classes, 4 subjects, 7 courses', () async {
      mockRealAssets();
      addTearDown(clearMock);
      final index = await loadSyllabusIndex();

      expect(index.board.value, 'cbse');
      expect(index.syllabusVersion, '2026-27');
      expect(index.classes.length, 2);

      final class9 = index.classes.firstWhere((c) => c.klass == 9);
      final class10 = index.classes.firstWhere((c) => c.klass == 10);
      expect(class9.subjects.length, 2);
      expect(class10.subjects.length, 2);

      expect(index.allCourses.length, 7);

      // Class 9 Hindi has BOTH आर-1 and आर-2 variants from the same PDF.
      final hindi9 = class9.subjects.firstWhere((s) => s.id == 'hindi');
      expect(hindi9.courses.length, 2);
      expect(hindi9.courses.map((c) => c.id).toSet(),
          {'cbse_9_hindi_r1', 'cbse_9_hindi_r2'});

      // Class 10 Sanskrit has both विषयगत (122) and संप्रेषणात्मक (119).
      final sanskrit10 = class10.subjects.firstWhere((s) => s.id == 'sanskrit');
      expect(sanskrit10.courses.length, 2);
    });

    test('literatureStatus is pending exactly for the three Class 9 tracks',
        () {
      final file = File('assets/syllabus/cbse/index.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final index = SyllabusIndex.fromJson(json);

      for (final course in index.allCourses) {
        final expectedPending = course.id.startsWith('cbse_9_');
        expect(course.literaturePending, expectedPending, reason: course.id);
      }
    });

    test('courseById finds and misses correctly', () {
      final file = File('assets/syllabus/cbse/index.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final index = SyllabusIndex.fromJson(json);

      expect(index.courseById('cbse_10_hindi_a'), isNotNull);
      expect(index.courseById('cbse_10_hindi_a')!.name, 'हिन्दी मातृभाषा (अ)');
      expect(index.courseById('cbse_11_physics'), isNull);
    });
  });

  group('syllabus loader', () {
    test('loads a real course end-to-end via mocked asset bundle', () async {
      mockRealAssets();
      addTearDown(clearMock);

      final syllabus = await loadCourseSyllabus('cbse_10_sanskrit');
      expect(syllabus, isNotNull);
      expect(syllabus!.id.value, 'cbse_10_sanskrit');
      expect(syllabus.computedBoardMarks, 80);
      expect(syllabus.validate(), isEmpty);
    });

    test('returns null for an unknown track (never throws)', () async {
      mockRealAssets();
      addTearDown(clearMock);
      final result = await loadCourseSyllabus('cbse_99_physics');
      expect(result, isNull);
    });

    test('returns null when the asset channel is unavailable', () async {
      mockMissingAssets();
      addTearDown(clearMock);
      final result = await loadCourseSyllabus('cbse_10_sanskrit');
      expect(result, isNull);
    });

    test('index loader degrades to an empty index when assets are missing',
        () async {
      mockMissingAssets();
      addTearDown(clearMock);
      final index = await loadSyllabusIndex();
      expect(index.classes, isEmpty);
      expect(index.board.value, 'cbse');
    });
  });

  group('SyllabusRepository caching', () {
    test('loads every V1 course exactly once and validates all', () async {
      mockRealAssets();
      addTearDown(clearMock);

      final repo = SyllabusRepository();
      final courses = await repo.allCourses();

      expect(courses.length, 7);
      for (final course in courses) {
        expect(course.validate(), isEmpty, reason: course.id.value);
      }

      // Cache hit: same instance identity on the second call.
      final again = await repo.course('cbse_10_sanskrit');
      expect(
          identical(again,
              courses.firstWhere((c) => c.id.value == 'cbse_10_sanskrit')),
          isTrue);

      repo.clearCache();
    });
  });

  group('Riverpod providers', () {
    test('courseSyllabusProvider serves validated course data', () async {
      mockRealAssets();
      addTearDown(clearMock);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final syllabus = await container
          .read(courseSyllabusProvider('cbse_9_sanskrit').future);
      expect(syllabus, isNotNull);
      expect(syllabus!.hasPendingLiterature, isTrue);
    });

    test('syllabusIndexProvider serves the catalog', () async {
      mockRealAssets();
      addTearDown(clearMock);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final index = await container.read(syllabusIndexProvider.future);
      expect(index.allCourses.length, 7);
    });
  });

  group('board-agnostic contract (ICSE-ready, not ICSE-built)', () {
    test('SyllabusTrackId assetPath derives from the board segment', () {
      final id = SyllabusTrackId.parse('icse_10_hindi_a');
      expect(id.assetPath, 'assets/syllabus/icse/icse_10_hindi_a.json');
      expect(id.board.isSupported, isTrue);
    });

    test('CBSE data contains no CBSE-specific code assumptions', () async {
      // The loader resolves paths purely from data: track id → file name.
      // This test documents that contract by loading via the index.
      mockRealAssets();
      addTearDown(clearMock);

      final index = await loadSyllabusIndex();
      for (final entry in index.allCourses) {
        final file = File('assets/syllabus/${index.board.value}/${entry.file}');
        expect(file.existsSync(), isTrue,
            reason: '${entry.id} must resolve to a bundled file');
      }
    });
  });
}
