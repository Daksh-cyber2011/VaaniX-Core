/// Generated Content Repository — M5 persistence tests.
///
/// Pins the §35/§61 cache contract: key `learn_profile_<iso>_gen` inside
/// the M2 namespace, JSON round-trips, the 12-entry bound (oldest
/// evicted), the 7-day freshness policy, corruption safety (missing /
/// malformed / wrong-language values degrade to "nothing cached", never
/// crash), and the prefix-scoped reset covering the new key.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/data/learn_profile_repository.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';

Future<({GeneratedContentRepository repo, ILocalStorageService storage})>
    _make({Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  return (
    repo: GeneratedContentRepository(storage),
    storage: storage,
  );
}

var _id = 0;

GeneratedContent _content(
  String languageCode, {
  DateTime? createdAt,
  String kind = 'explanation',
}) {
  _id++;
  return GeneratedContent(
    id: 'gen-test-$_id',
    kind: GeneratedContentKind.values.firstWhere((k) => k.name == kind),
    languageCode: languageCode,
    conceptId: 'hi_ls_greetings',
    lessonId: 'hi_ls_greetings',
    difficultyKnob: 2,
    title: 'Made for you',
    body: kind == 'explanation' ? 'नमस्ते is a warm hello.' : null,
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  group('generated-content persistence', () {
    test('unset language reads as null', () async {
      final m = await _make();
      expect(
        m.repo.get(LearnLanguage.hindi, 'hi_ls_greetings|explanation|2'),
        isNull,
      );
    });

    test('save + get round-trips the item under its key', () async {
      final m = await _make();
      const key = 'hi_ls_greetings|explanation|2';
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));

      final restored = m.repo.get(LearnLanguage.hindi, key);
      expect(restored, isNotNull);
      expect(restored!.languageCode, 'hi');
      expect(restored.kind, GeneratedContentKind.explanation);
      expect(restored.conceptId, 'hi_ls_greetings');
      expect(m.repo.has(LearnLanguage.hindi, key), isTrue);
    });

    test('caches are per-language and do not leak', () async {
      final m = await _make();
      const key = 'hi_ls_greetings|explanation|2';
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));

      expect(m.repo.get(LearnLanguage.bengali, key), isNull);
    });

    test('an item stored under a WRONG language key is rejected', () async {
      final m = await _make();
      // Drift simulation: Bengali content physically under the Hindi key.
      await m.storage.setString(
        GeneratedContentRepository.cacheKey(LearnLanguage.hindi),
        jsonEncode({
          'version': 1,
          'items': [
            {
              'key': 'hi_ls_greetings|explanation|2',
              'content': _content('bn').toJson(),
            },
          ],
        }),
      );
      expect(
        m.repo.get(LearnLanguage.hindi, 'hi_ls_greetings|explanation|2'),
        isNull,
      );
    });

    test('upsert replaces the same key without duplicating', () async {
      final m = await _make();
      const key = 'hi_ls_greetings|explanation|2';
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));

      final raw =
          m.storage.getString(GeneratedContentRepository.cacheKey(LearnLanguage.hindi))!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect((decoded['items'] as List).length, 1);
    });

    test('the store is bounded at ${GeneratedContentRepository.maxEntries} '
        '(oldest evicted)', () async {
      final m = await _make();
      for (var i = 0; i < GeneratedContentRepository.maxEntries + 3; i++) {
        await m.repo.save(
          LearnLanguage.hindi,
          'concept|$i|2',
          _content('hi'),
        );
      }
      final raw =
          m.storage.getString(GeneratedContentRepository.cacheKey(LearnLanguage.hindi))!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['items'] as List;
      expect(items.length, GeneratedContentRepository.maxEntries);
      // The OLDEST keys were evicted; the newest survive.
      expect(
        m.repo.get(LearnLanguage.hindi, 'concept|0|2'),
        isNull,
      );
      expect(
        m.repo.get(
          LearnLanguage.hindi,
          'concept|${GeneratedContentRepository.maxEntries + 2}|2',
        ),
        isNotNull,
      );
    });

    test('clear removes exactly that language cache', () async {
      final m = await _make();
      const key = 'hi_ls_greetings|explanation|2';
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));
      await m.repo.save(LearnLanguage.urdu, key, _content('ur'));

      await m.repo.clear(LearnLanguage.hindi);

      expect(m.repo.get(LearnLanguage.hindi, key), isNull);
      expect(m.repo.get(LearnLanguage.urdu, key), isNotNull);
    });

    test('corrupt storage degrades to nothing cached, never throws',
        () async {
      final m = await _make(seed: {
        'learn_profile_hi_gen': '{definitely not json',
      });
      expect(
        m.repo.get(LearnLanguage.hindi, 'hi_ls_greetings|explanation|2'),
        isNull,
      );
    });

    test('the M2 prefix reset (clearAll) covers the generated cache',
        () async {
      final m = await _make();
      const key = 'hi_ls_greetings|explanation|2';
      await m.repo.save(LearnLanguage.hindi, key, _content('hi'));

      await LearnProfileRepository(m.storage).clearAll();

      expect(m.repo.get(LearnLanguage.hindi, key), isNull);
    });
  });

  group('freshness policy', () {
    test('a brand-new item is fresh', () {
      expect(
        GeneratedContentRepository.isFresh(_content('hi')),
        isTrue,
      );
    });

    test('a week-old item is stale', () {
      final old = _content(
        'hi',
        createdAt: DateTime.now().subtract(
          GeneratedContentRepository.kDefaultMaxAge +
              const Duration(hours: 1),
        ),
      );
      expect(GeneratedContentRepository.isFresh(old), isFalse);
    });

    test('a future timestamp (clock skew) counts as fresh', () {
      final future = _content(
        'hi',
        createdAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(GeneratedContentRepository.isFresh(future), isTrue);
    });
  });
}
