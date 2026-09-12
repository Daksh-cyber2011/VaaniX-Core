/// Personalized Content Generator flow — M5 tests.
///
/// Walks the §34 ladder hop by hop with a COUNTING fake text client:
/// cached personalization (zero network) → ONE grounded AI call →
/// validated write-through → typed Lefts for offline / empty-excerpt /
/// decline / garbage, and the §46 guarantee that nothing ever throws
/// while the caller keeps its trusted fallback.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/errors/failures.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/learn/data/generated_content_repository.dart';
import 'package:vaanix_app/features/learn/data/gemini_planner.dart';
import 'package:vaanix_app/features/learn/data/personalized_content_generator.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/domain/spine/content_registry.dart';
import 'package:vaanix_app/features/learn/domain/spine/generated_content.dart';

/// Counting fake for the raw-text boundary — the ONLY network hop.
class _CountingClient implements PlannerTextClient {
  _CountingClient({this.available = true, this.response});

  final bool available;

  /// Raw reply; `null` makes [complete] throw (hard failure path).
  final String? response;
  int completeCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    completeCalls++;
    if (response == null) throw StateError('backend exploded');
    return response!;
  }
}

/// Storage whose writes fail (disk-full simulation): reads still work.
/// Everything else is delegated (only the generated-cache write is
/// expected in this test's path).
class _DiskFullStorage implements ILocalStorageService {
  _DiskFullStorage(this._inner);

  final ILocalStorageService _inner;

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    throw const _SimulatedDiskFull();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => _invokedDelegate(invocation);

  dynamic _invokedDelegate(Invocation invocation) {
    // Delegate the remaining interface members to the real storage so
    // any unexpected touch behaves honestly.
    throw UnimplementedError('unexpected member: ${invocation.memberName}');
  }
}

class _SimulatedDiskFull implements Exception {
  const _SimulatedDiskFull();
}

const _excerpt = TrustedKnowledgeExcerpt(
  languageCode: 'hi',
  conceptId: 'hi_c1',
  lessonId: 'hi_c1',
  vocabulary: ['नमस्ते', 'दोस्त'],
  exampleSentences: ['नमस्ते दोस्त'],
  referenceText: 'नमस्ते दोस्त — hello friend.',
  isRTL: false,
  scriptCode: 'Deva',
);

const _emptyExcerpt = TrustedKnowledgeExcerpt(
  languageCode: 'hi',
  conceptId: 'hi_c1',
  lessonId: 'hi_c1',
  vocabulary: [],
  exampleSentences: [],
  referenceText: '',
  isRTL: false,
  scriptCode: 'Deva',
);

const _validExplanation =
    '{"kind":"explanation","language":"hi","title":"नमस्ते again",'
    '"body":"नमस्ते is the friendly hello your lesson taught."}';

const _ungroundedExplanation =
    '{"kind":"explanation","language":"hi","title":"x",'
    '"body":"Totally unrelated filler with no trusted words."}';

const _digest = <String, Object?>{'language': 'hi'};

Future<GeneratedContentRepository> _newRepo() async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  return GeneratedContentRepository(LocalStorageService(prefs));
}

Future<Either<Failure, GeneratedContentResult>> _generate({
  required PlannerTextClient client,
  GeneratedContentRepository? cache,
  TrustedKnowledgeExcerpt excerpt = _excerpt,
  bool useCache = true,
}) =>
    PersonalizedContentGenerator(
      textClient: client,
      cache: cache,
    ).generate(
      spec: learnLanguageSpec(LearnLanguage.hindi),
      conceptId: 'hi_c1',
      conceptTitle: 'Greetings',
      conceptSubtitle: null,
      excerpt: excerpt,
      kind: GeneratedContentKind.explanation,
      difficultyKnob: 2,
      learnerDigest: _digest,
      useCache: useCache,
    );

GeneratedContent _seedItem({
  required String id,
  DateTime? createdAt,
  String body = 'नमस्ते is the friendly hello your lesson taught.',
}) =>
    GeneratedContent(
      id: id,
      kind: GeneratedContentKind.explanation,
      languageCode: 'hi',
      conceptId: 'hi_c1',
      lessonId: 'hi_c1',
      difficultyKnob: 2,
      title: 'नमस्ते again',
      body: body,
      createdAt: createdAt ?? DateTime.now(),
    );

void main() {
  group('§34 ladder — cache → AI → write-through', () {
    test('hop 2: a cache hit is served with ZERO network calls', () async {
      final repo = await _newRepo();
      const key = 'hi_c1|explanation|2';
      await repo.save(
        LearnLanguage.hindi,
        key,
        _seedItem(id: 'gen-seeded-1'),
      );

      final client = _CountingClient(response: _validExplanation);
      final material = await _unwrapRight(client: client, cache: repo);

      expect(material.fromCache, isTrue);
      expect(material.content.id, 'gen-seeded-1');
      expect(client.completeCalls, 0);
    });

    test('hop 3: a cache miss makes ONE call and writes through', () async {
      final repo = await _newRepo();
      final client = _CountingClient(response: _validExplanation);

      final result = await _generate(client: client, cache: repo);

      expect(result.isRight(), isTrue);
      final material = result.fold(
        (f) => throw StateError(f.message),
        (r) => r,
      );
      expect(material.fromCache, isFalse);
      expect(client.completeCalls, 1);
      expect(
        repo.get(
          LearnLanguage.hindi,
          'hi_c1|explanation|2',
        ),
        isNotNull,
      );
    });

    test('grounding is enforced on FRESH output too (garbage → Left)',
        () async {
      final client = _CountingClient(response: _ungroundedExplanation);
      final failure = await _captureLeft(client: client);
      expect(failure, contains('not grounded'));
    });
  });

  group('refusals happen BEFORE any network call', () {
    test('offline / unconfigured client → Left, zero calls', () async {
      final client = _CountingClient(available: false);
      await _captureLeft(client: client);
      expect(client.completeCalls, 0);
    });

    test('empty excerpt → Left, zero calls (§16 fail-closed)', () async {
      final client = _CountingClient(response: _validExplanation);
      await _captureLeft(client: client, excerpt: _emptyExcerpt);
      expect(client.completeCalls, 0);
    });
  });

  group('model failure modes stay typed Lefts (§46)', () {
    test('the honest decline {"kind":"none"} is a Left, not an error',
        () async {
      final client = _CountingClient(response: '{"kind":"none"}');
      final failure = await _captureLeft(client: client);
      expect(failure, contains('declined'));
    });

    test('undecodable garbage is a Left; nothing is cached', () async {
      final repo = await _newRepo();
      final client = _CountingClient(response: '((( not json )))');
      await _captureLeft(client: client, cache: repo);
      expect(
        repo.get(
          LearnLanguage.hindi,
          'hi_c1|explanation|2',
        ),
        isNull,
      );
    });

    test('a hard client crash becomes a Left — never a throw', () async {
      final client = _CountingClient(); // response == null → throws
      await _captureLeft(client: client);
    });

    test(
        'disk-full never fails good material (write-through is '
        'best-effort)', () async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final flaky = _DiskFullStorage(LocalStorageService(prefs));
      final client = _CountingClient(response: _validExplanation);

      final material = await _unwrapRight(
        client: client,
        cache: GeneratedContentRepository(flaky),
      );
      expect(material.fromCache, isFalse);
      expect(client.completeCalls, 1);
    });

    test('useCache=false always goes to the model', () async {
      final repo = await _newRepo();
      await repo.save(
        LearnLanguage.hindi,
        'hi_c1|explanation|2',
        _seedItem(id: 'gen-seeded-2'),
      );

      final client = _CountingClient(response: _validExplanation);
      final material =
          await _unwrapRight(client: client, cache: repo, useCache: false);

      expect(material.fromCache, isFalse);
      expect(client.completeCalls, 1);
    });

    test('a STALE cached item is not served; the model runs', () async {
      final repo = await _newRepo();
      await repo.save(
        LearnLanguage.hindi,
        'hi_c1|explanation|2',
        _seedItem(
          id: 'gen-stale-1',
          createdAt: DateTime.now().subtract(
            GeneratedContentRepository.kDefaultMaxAge +
                const Duration(hours: 2),
          ),
        ),
      );

      final client = _CountingClient(response: _validExplanation);
      final material = await _unwrapRight(client: client, cache: repo);

      expect(material.fromCache, isFalse);
      expect(client.completeCalls, 1);
    });

    test(
        'a stored item that no longer validates is discarded, not '
        'served', () async {
      final repo = await _newRepo();
      // Grounding-broken stored item (no trusted token in the body).
      await repo.save(
        LearnLanguage.hindi,
        'hi_c1|explanation|2',
        _seedItem(
          id: 'gen-corrupt-1',
          body: 'Words that share nothing with the trusted excerpt at all.',
        ),
      );

      final client = _CountingClient(response: _validExplanation);
      final material = await _unwrapRight(client: client, cache: repo);

      // The model is called; the fresh material wins.
      expect(material.fromCache, isFalse);
      expect(client.completeCalls, 1);
      expect(material.content.id, isNot('gen-corrupt-1'));
    });
  });
}

/// Runs [generate] expecting a Right; returns the result.
Future<GeneratedContentResult> _unwrapRight({
  required PlannerTextClient client,
  GeneratedContentRepository? cache,
  TrustedKnowledgeExcerpt excerpt = _excerpt,
  bool useCache = true,
}) async {
  final result = await _generate(
    client: client,
    cache: cache,
    excerpt: excerpt,
    useCache: useCache,
  );
  expect(result.isRight(), isTrue, reason: 'expected a Right, got $result');
  return result.fold(
    (failure) => throw StateError('unexpected Left: ${failure.message}'),
    (r) => r,
  );
}

/// Runs [generate] expecting a Left; returns the failure message.
Future<String> _captureLeft({
  required PlannerTextClient client,
  GeneratedContentRepository? cache,
  TrustedKnowledgeExcerpt excerpt = _excerpt,
}) async {
  final result = await _generate(
    client: client,
    cache: cache,
    excerpt: excerpt,
  );
  expect(result.isLeft(), isTrue, reason: 'expected a Left, got $result');
  return result.fold((failure) => failure.message, (r) => 'UNEXPECTED $r');
}
