/// Exam Mode 2.0 — M2 Repository & Controller Tests
///
/// Persistence contract (SharedPreferences mock, real canonical assets via
/// the mocked asset channel) and controller behaviors: write-through
/// persistence, select all / clear all / section toggles, isolation,
/// prune-on-load, confirm (active track).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/exam/data/exam_scope_repository.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';

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

  Future<SharedPreferences> freshPrefs(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  CourseSyllabus courseFromDisk(String trackId) {
    final file = File('assets/syllabus/cbse/$trackId.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return CourseSyllabus.fromJson(json);
  }

  group('ExamScopeRepository persistence', () {
    late SharedPreferences prefs;
    late ExamScopeRepository repo;

    setUp(() async {
      prefs = await freshPrefs();
      repo = ExamScopeRepository(LocalStorageService(prefs));
    });

    test('empty store loads as null active / no scopes', () async {
      final store = await repo.load();
      expect(store.activeTrackId, isNull);
      expect(store.scopes, isEmpty);
      expect(await repo.activeTrackId(), isNull);
    });

    test('saveSelection persists and marks the track active', () async {
      const track = 'cbse_10_sanskrit';
      final selection =
          ExamScopeSelection.empty(track).toggle('${track}_grammar_sandhi')!;

      await repo.saveSelection(selection);
      expect(await repo.activeTrackId(), track);

      final loaded = await repo.loadSelection(track);
      expect(loaded.selectedUnitIds, selection.selectedUnitIds);
      expect(loaded.revision, selection.revision);

      // Another track's scope stays independent (course isolation at the
      // storage layer).
      const other = 'cbse_10_hindi_a';
      final otherEmpty = await repo.loadSelection(other);
      expect(otherEmpty.isEmpty, isTrue);
      expect(otherEmpty.trackId, other);
    });

    test('clearSelection empties but keeps the track active', () async {
      const track = 'cbse_10_hindi_b';
      await repo.saveSelection(ExamScopeSelection.empty(track)
          .selectAll(['${track}_grammar_padbandh']));
      await repo.clearSelection(track);
      expect((await repo.loadSelection(track)).isEmpty, isTrue);
      expect(await repo.activeTrackId(), track);
    });

    test('corrupt JSON degrades to an empty store, never crashes', () async {
      final corruptPrefs = await freshPrefs({'exam_scope_v1': '{not json'});
      final store =
          await ExamScopeRepository(LocalStorageService(corruptPrefs)).load();
      expect(store.activeTrackId, isNull);
      expect(store.scopes, isEmpty);
    });

    test('one corrupt track entry does not take down the store', () async {
      final json = jsonEncode({
        'version': 1,
        'activeTrackId': 'cbse_10_sanskrit',
        'scopes': {
          'cbse_10_sanskrit': {
            'trackId': 'cbse_10_sanskrit',
            'selectedUnitIds': ['cbse_10_sanskrit_grammar_samasa'],
            'revision': 2,
            'updatedAtIso': ''
          },
          'cbse_9_sanskrit': {'trackId': 3}, // corrupt entry
        },
      });
      final mixedPrefs = await freshPrefs({'exam_scope_v1': json});
      final store =
          await ExamScopeRepository(LocalStorageService(mixedPrefs)).load();
      expect(store.activeTrackId, 'cbse_10_sanskrit');
      expect(store.scopes.containsKey('cbse_10_sanskrit'), isTrue);
      expect(store.scopes.containsKey('cbse_9_sanskrit'), isFalse);
    });

    test('loadAndPrune drops stale ids and persists the repair', () async {
      const track = 'cbse_10_sanskrit';
      await repo.saveSelection(ExamScopeSelection.fromJson({
        'trackId': track,
        'selectedUnitIds': [
          '${track}_grammar_sandhi',
          '${track}_no_longer_exists',
        ],
        'revision': 5,
        'updatedAtIso': '',
      }));

      final view = ExamScopeView.fromSyllabus(courseFromDisk(track));
      final store = await repo.loadAndPrune({track: view});
      expect(store.scopes[track]!.selectedUnitIds, {'${track}_grammar_sandhi'});
      // Repair persisted.
      final reloaded = await repo.loadSelection(track);
      expect(reloaded.selectedUnitIds, {'${track}_grammar_sandhi'});
    });
  });

  group('ExamScopeController', () {
    late SharedPreferences prefs;

    setUp(() async {
      prefs = await freshPrefs();
      mockRealAssets();
      addTearDown(clearAssets);
    });

    Future<ProviderContainer> makeContainer() async {
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('builds with the validated syllabus view and empty scope', () async {
      const track = 'cbse_10_sanskrit';
      final container = await makeContainer();
      final state = await container.read(examScopeProvider(track).future);
      expect(state.isReady, isTrue);
      expect(state.view!.trackId, track);
      expect(state.selection.isEmpty, isTrue);
      expect(state.totalSelectable, state.view!.selectableUnitIds.length);
    });

    test('unknown track fails instead of faking a syllabus', () async {
      final container = await makeContainer();
      expect(() => container.read(examScopeProvider('cbse_99_physics').future),
          throwsA(isA<StateError>()));
    });

    test('toggleUnit is write-through persisted', () async {
      const track = 'cbse_10_hindi_b';
      const unitId = '${track}_grammar_samasa';
      final container = await makeContainer();
      final controller = container.read(examScopeProvider(track).notifier);

      await controller.toggleUnit(unitId);
      final state = await container.read(examScopeProvider(track).future);
      expect(state.selection.isSelected(unitId), isTrue);
      expect(state.selection.revision, 1);

      // Persisted: a fresh container (same prefs) sees the same selection.
      final container2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container2.dispose);
      final state2 = await container2.read(examScopeProvider(track).future);
      expect(state2.selection.isSelected(unitId), isTrue);
      expect(state2.selection.revision, 1);
    });

    test('selectAll / toggleSection / clearAll round-trips', () async {
      const track = 'cbse_10_sanskrit';
      final container = await makeContainer();
      final controller = container.read(examScopeProvider(track).notifier);

      await controller.selectAll();
      var state = await container.read(examScopeProvider(track).future);
      expect(state.selectedCount, state.totalSelectable);
      expect(state.selection.revision, 1);

      // Grammar section toggle removes exactly the grammar units.
      final grammarSection =
          state.view!.sections.firstWhere((s) => s.stableKey == 'grammar');
      final grammarCount = grammarSection.selectableUnits.length;
      await controller.toggleSection(grammarSection.id);
      state = await container.read(examScopeProvider(track).future);
      expect(state.selectedCount, state.totalSelectable - grammarCount);

      await controller.clearAll();
      state = await container.read(examScopeProvider(track).future);
      expect(state.selection.isEmpty, isTrue);
    });

    test('foreign unit id is an ignored no-op (isolation)', () async {
      const track = 'cbse_10_sanskrit';
      final container = await makeContainer();
      final controller = container.read(examScopeProvider(track).notifier);

      await controller.toggleUnit('cbse_10_hindi_a_grammar_vachya');
      final state = await container.read(examScopeProvider(track).future);
      expect(state.selection.isEmpty, isTrue);
      expect(state.selection.revision, 0);
    });

    test('stale stored ids are pruned at build time', () async {
      const track = 'cbse_10_sanskrit';
      final stale = ExamScopeSelection.fromJson({
        'trackId': track,
        'selectedUnitIds': [
          '${track}_grammar_sandhi',
          '${track}_ghost_topic',
        ],
        'revision': 9,
        'updatedAtIso': 'x',
      }).toJson();

      final seeded = await freshPrefs({
        'exam_scope_v1': jsonEncode({
          'version': 1,
          'activeTrackId': track,
          'scopes': {track: stale},
        })
      });

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(seeded),
      ]);
      addTearDown(container.dispose);
      final state = await container.read(examScopeProvider(track).future);
      expect(state.selection.selectedUnitIds, {'${track}_grammar_sandhi'});
      expect(state.selection.revision, 9,
          reason: 'prune is a repair, not a user action');
    });

    test('confirmSelection marks the track active', () async {
      const track = 'cbse_9_hindi_r1';
      final container = await makeContainer();
      final controller = container.read(examScopeProvider(track).notifier);

      await controller.selectAll();
      await controller.confirmSelection();

      expect(
          await ExamScopeRepository(LocalStorageService(prefs)).activeTrackId(),
          track);
    });
  });
}
