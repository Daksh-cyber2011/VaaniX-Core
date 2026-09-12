/// Exam Mode 2.0 — M2 Widget Tests (Scope Flow)
///
/// Drives the three real screens against the REAL canonical syllabus
/// assets (mocked asset channel) + mocked SharedPreferences:
///  * track selection (board → class → subject → course),
///  * scope selection (select all / clear all / section / individual,
///    pending literature, internal-only chapters),
///  * summary + confirm persistence.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/exam_scope_repository.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_scope_selection_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_scope_summary_screen.dart';
import 'package:vaanix_app/features/exam/presentation/screens/exam_track_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void clearAssets() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockRealAssets();
  });

  tearDown(clearAssets);

  ExamScopeView viewFromDisk(String trackId) {
    final file = File('assets/syllabus/cbse/$trackId.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ExamScopeView.fromSyllabus(CourseSyllabus.fromJson(json));
  }

  Future<SharedPreferences> seedActiveSelection(String trackId) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'exam_scope_v1': jsonEncode({
        'version': 1,
        'activeTrackId': trackId,
        'scopes': {
          trackId: ExamScopeSelection.empty(trackId)
              .selectAll(viewFromDisk(trackId).selectableUnitIds)
              .toJson(),
        },
      }),
    });
    return SharedPreferences.getInstance();
  }

  Widget host(SharedPreferences prefs, Widget child) =>
      UncontrolledProviderScope(
        container: ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]),
        child: MaterialApp(home: child),
      );

  testWidgets('track selection: catalog renders and full pick flow works',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(host(prefs, const ExamTrackSelectionScreen()));
    await tester.pumpAndSettle();

    // Board step: CBSE selected, ICSE explicitly not built.
    expect(find.text('CBSE'), findsOneWidget);
    expect(find.text('ICSE'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsOneWidget);

    // Class step.
    expect(find.text('Class 9'), findsOneWidget);
    expect(find.text('Class 10'), findsOneWidget);
    await tester.tap(find.text('Class 10'));
    await tester.pumpAndSettle();

    // Subject step.
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('संस्कृतम्'), findsOneWidget);
    await tester.tap(find.text('संस्कृतम्'));
    await tester.pumpAndSettle();

    // Course step: both Sanskrit variants with subject codes.
    expect(find.text('संस्कृतम् (संप्रेषणात्मकम्)'), findsOneWidget);
    expect(find.textContaining('Subject code 119'), findsOneWidget);
    expect(find.textContaining('Subject code 122'), findsOneWidget);

    // Continue disabled until a course is picked.
    ElevatedButton buttonOf(String label) => tester.widget<ElevatedButton>(find
        .ancestor(of: find.text(label), matching: find.byType(ElevatedButton))
        .first);

    expect(buttonOf('View official syllabus').onPressed, isNull);

    // Pick the plain संस्कृतम् course card (last occurrence after the
    // subject card with the same title).
    await tester.tap(find.text('संस्कृतम्').last);
    await tester.pumpAndSettle();

    expect(buttonOf('View official syllabus').onPressed, isNotNull,
        reason: 'course picked → continue enabled');
  });

  testWidgets('track selection: continue-editing card for saved scope',
      (tester) async {
    final prefs = await seedActiveSelection('cbse_10_sanskrit');
    await tester.pumpWidget(host(prefs, const ExamTrackSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Continue:'), findsOneWidget);
    expect(find.textContaining('इकाइयाँ चयनित'), findsOneWidget);
  });

  testWidgets(
      'scope selection: sections render, select all works, pending Class 9 shown',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(host(
        prefs, const ExamScopeSelectionScreen(trackId: 'cbse_9_sanskrit')));
    await tester.pumpAndSettle();

    // All four official sections render.
    expect(find.text('अपठितावबोधनम्'), findsOneWidget);
    expect(find.text('रचनात्मककार्यम्'), findsOneWidget);
    expect(find.text('अनुप्रयुक्तव्याकरणम्'), findsOneWidget);
    expect(find.text('पठितावबोधनम्'), findsOneWidget);

    // Pending literature: honest awaiting banner.
    expect(find.textContaining('आधिकारिक अध्याय सूची'), findsOneWidget);

    // Grammar topics render (Devanagari titles from canonical data).
    expect(find.text('सन्धिः'), findsOneWidget);
    expect(find.text('कारक-उपपद-विभक्तयः'), findsOneWidget);

    // Select All → the summary bar count updates.
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(
        find
            .textContaining(RegExp(r'^\d+ / \d+ इकाइयाँ'))
            .evaluate()
            .isNotEmpty,
        isTrue);

    // Clear All → back to zero (9 Sanskrit grammar items with शब्दरूपाणि etc.
    // minus literature: 1 + 3 + 9 = 13 selectable units).
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 13 इकाइयाँ'), findsOneWidget);
  });

  testWidgets('scope selection (119): internal-only chapters not selectable',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(host(
        prefs,
        const ExamScopeSelectionScreen(
            trackId: 'cbse_10_sanskrit_communicative')));
    await tester.pumpAndSettle();

    expect(find.text('कालोऽहम्'), findsOneWidget);
    expect(find.text('किं किम् उपादेयम्'), findsOneWidget);
    expect(find.textContaining('आंतरिक मूल्यांकन हेतु'), findsNWidgets(2));

    // Behavioral guarantee: tapping an internal-only chapter changes
    // nothing (0 selected before and after).
    await tester.tap(find.text('कालोऽहम्'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 20 इकाइयाँ'), findsOneWidget,
        reason: 'internal-only chapters must never enter board scope');

    // Their checkboxes are disabled.
    final ch10Checkbox = tester.widget<Checkbox>(find
        .ancestor(of: find.text('कालोऽहम्'), matching: find.byType(Checkbox))
        .first);
    expect(ch10Checkbox.onChanged, isNull);
  });

  testWidgets('scope selection: individual + section toggles persist',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(host(
        prefs, const ExamScopeSelectionScreen(trackId: 'cbse_10_sanskrit')));
    await tester.pumpAndSettle();

    // 20 selectable units: 1 (unread) + 3 (writing) + 7 (grammar)
    // + 9 (chapters).
    expect(find.text('0 / 20 इकाइयाँ'), findsOneWidget);

    // Individual: tap the सन्धि tile.
    await tester.tap(find.text('सन्धिः'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20 इकाइयाँ'), findsOneWidget);

    // Section: tap the grammar section header (tristate checkbox row).
    await tester.tap(find.text('अनुप्रयुक्तव्याकरणम्'));
    await tester.pumpAndSettle();
    expect(find.text('8 / 20 इकाइयाँ'), findsOneWidget,
        reason: 'grammar section adds its 7 units to the 1 selected');

    // Write-through persistence: a fresh screen instance sees the scope.
    await tester.pumpWidget(host(
        prefs, const ExamScopeSelectionScreen(trackId: 'cbse_10_sanskrit')));
    await tester.pumpAndSettle();
    expect(find.text('8 / 20 इकाइयाँ'), findsOneWidget,
        reason: 'selection persisted across instances');
  });

  testWidgets('summary: identity, totals, confirm persists active track',
      (tester) async {
    final prefs = await seedActiveSelection('cbse_10_sanskrit');
    await tester.pumpWidget(
        host(prefs, const ExamScopeSummaryScreen(trackId: 'cbse_10_sanskrit')));
    await tester.pumpAndSettle();

    // Identity rows (§49).
    expect(find.text('CBSE'), findsOneWidget);
    expect(find.text('Class 10'), findsOneWidget);
    expect(find.text('संस्कृतम्'), findsWidgets);
    expect(find.textContaining('Official CBSE 2026-27'), findsOneWidget);

    // Per-section row present.
    expect(find.text('अनुप्रयुक्तव्याकरणम्'), findsOneWidget);

    // Confirm → success card.
    await tester.tap(find.text('Confirm Scope'));
    await tester.pumpAndSettle();
    expect(find.text('दायरा सहेज दिया गया'), findsOneWidget);

    // Persisted as the ACTIVE track.
    final store = await ExamScopeRepository(LocalStorageService(prefs)).load();
    expect(store.activeTrackId, 'cbse_10_sanskrit');
  });

  testWidgets('summary (Class 9): pending literature note shown honestly',
      (tester) async {
    final prefs = await seedActiveSelection('cbse_9_sanskrit');
    await tester.pumpWidget(
        host(prefs, const ExamScopeSummaryScreen(trackId: 'cbse_9_sanskrit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('आधिकारिक अध्याय सूची जारी होने बाकी'),
        findsOneWidget);
  });
}
