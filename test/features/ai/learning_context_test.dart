/// LearningContext Pipeline Tests (V1 §4)
///
/// Proves the full context chain with REAL production code:
///   LearningContext → learningContextProvider → ChatController stamp →
///   ConversationContext.learningContextFragment → PromptPipeline persona →
///   adapter-visible context.
///
/// The injection tests are the contract: if the fragment stops reaching
/// the persona prompt (or the context stops reaching the adapter), these
/// tests fail loudly instead of silently degrading personalization.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/data/conversation_pipeline_impl.dart';
import 'package:vaanix_app/features/ai/data/default_prompt_pipeline.dart';
import 'package:vaanix_app/features/ai/data/safety_filter.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/ai_service.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_memory.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/domain/learning_context.dart';
import 'package:vaanix_app/features/ai/domain/model_adapter.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/ai/presentation/providers/learning_context_provider.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/learn/data/curriculum_loader.dart';
import 'package:vaanix_app/features/profile/presentation/providers/profile_providers.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _CapturingService implements AIService {
  ConversationContext? lastContext;

  @override
  Map<AiProviderId, ModelAdapter> get adapters => const {};

  @override
  ModelAdapter adapterFor(AiConfig config) => throw UnimplementedError();

  @override
  Future<Result<AiMessage>> complete({
    required ConversationContext context,
    required AiConfig config,
  }) {
    lastContext = context;
    return Future.value(ok(AiMessage.assistant(
      id: 'a1',
      content: 'A gentle offline reply.',
    )));
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiConfig config,
  }) =>
      const Stream.empty();

  @override
  void dispose() {}
}

class _StubPipeline implements ConversationPipeline {
  _StubPipeline({required this.onSend});

  final void Function(ConversationContext context) onSend;

  @override
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async {
    onSend(context);
    return ok(
      context.append(AiMessage.assistant(id: 'a', content: 'reply')),
    );
  }

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) =>
      const Stream.empty();
}

class _MemoryStub implements ConversationMemory {
  @override
  Future<Result<List<AiMessage>>> load(String conversationId) async =>
      ok(const []);

  @override
  Future<Result<void>> append({
    required String conversationId,
    required AiMessage message,
  }) async =>
      ok(null);

  @override
  Future<Result<void>> save({
    required String conversationId,
    required List<AiMessage> messages,
  }) async =>
      ok(null);

  @override
  Future<Result<void>> clear(String conversationId) async => ok(null);

  @override
  Future<Result<void>> clearAll() async => ok(null);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LearningContext.bounded factory', () {
    test('caps weak titles at maxWeakTitlesInContext', () {
      final ctx = LearningContext.bounded(
        weakLessonTitles: const ['a', 'b', 'c', 'd', 'e', 'f'],
      );
      expect(ctx.weakLessonTitles.length, maxWeakTitlesInContext);
      expect(ctx.weakLessonTitles, ['a', 'b', 'c']);
    });

    test('truncates over-long titles with an ellipsis', () {
      final ctx = LearningContext.bounded(
        currentLessonTitle: 'x' * (maxTitleLength + 50),
      );
      expect(ctx.currentLessonTitle!.length, maxTitleLength + 1);
      expect(ctx.currentLessonTitle!.endsWith('…'), isTrue);
    });

    test('drops blank titles and clamps negative counters', () {
      final ctx = LearningContext.bounded(
        currentChapterTitle: '   ',
        lessonsCompleted: -5,
        currentStreak: -1,
        weakLessonTitles: const ['', '  ', 'real'],
      );
      expect(ctx.currentChapterTitle, isNull);
      expect(ctx.lessonsCompleted, 0);
      expect(ctx.currentStreak, 0);
      expect(ctx.weakLessonTitles, ['real']);
    });
  });

  group('LearningContext.fragment', () {
    test('empty context renders an empty fragment (nothing injected)', () {
      expect(LearningContext.empty.fragment, '');
      expect(LearningContext.empty.isEmpty, isTrue);
    });

    test('contains real progress, next step, and weak topics', () {
      final ctx = LearningContext.bounded(
        currentChapterTitle: 'Devanagari Basics',
        nextActionLabel: 'Practice: Vowel matras',
        nextActionHint: '1 of 4 exercises mastered',
        lessonsCompleted: 3,
        lessonsTotal: 13,
        currentStreak: 4,
        weakLessonTitles: const ['Vowel matras', 'Sandhi'],
      );
      final f = ctx.fragment;
      expect(f, contains('LEARNING CONTEXT'));
      expect(f, contains('3 of 13 lessons'));
      expect(f, contains('Day streak: 4'));
      expect(f, contains('Current chapter: Devanagari Basics'));
      expect(f, contains('Suggested next step: Practice: Vowel matras'));
      expect(f, contains('Topics to revisit: Vowel matras, Sandhi.'));
    });

    test('never exceeds maxFragmentLength even with extreme input', () {
      final ctx = LearningContext.bounded(
        nextActionHint: 'z' * 5000,
        currentChapterTitle: 'y' * 5000,
      );
      expect(ctx.fragment.length, lessThanOrEqualTo(maxFragmentLength + 1));
    });
  });

  group('ConversationContext carries the learning context', () {
    test('learningContextFragment mirrors learningContext.fragment', () {
      final ctx =
          LearningContext.bounded(nextActionLabel: 'Continue: Greetings');
      final cc = ConversationContext(
        conversationId: 'c1',
        learner: const LearnerContext(),
        messages: const [],
        learningContext: ctx,
      );
      expect(cc.learningContextFragment, ctx.fragment);
      expect(cc.learningContextFragment, contains('Continue: Greetings'));
    });

    test('default context has an empty fragment', () {
      const cc = ConversationContext(
        conversationId: 'c1',
        learner: LearnerContext(),
        messages: [],
      );
      expect(cc.learningContextFragment, '');
    });

    test('append / truncated / withPersona preserve the learning context',
        () {
      final lc = LearningContext.bounded(currentChapterTitle: 'Ch 1');
      final base = ConversationContext(
        conversationId: 'c1',
        learner: const LearnerContext(),
        messages: [AiMessage.user(id: 'u', content: 'hi')],
        learningContext: lc,
      );
      expect(
        base
            .append(AiMessage.assistant(id: 'a', content: 'namaste'))
            .learningContext,
        lc,
      );
      expect(base.truncated(keep: 1).learningContext, lc);
      expect(base.withPersona('P').learningContext, lc);
      expect(
        ConversationContext.initial(
          conversationId: 'c2',
          learner: const LearnerContext(),
          learningContext: lc,
        ).learningContext,
        lc,
      );
    });
  });

  group('DefaultPromptPipeline injects the fragment', () {
    const pipeline = DefaultPromptPipeline();

    test('persona includes the learning context fragment verbatim', () {
      final lc = LearningContext.bounded(
        currentChapterTitle: 'Devanagari Basics',
        nextActionLabel: 'Practice: Vowel matras',
        lessonsCompleted: 3,
        lessonsTotal: 13,
        weakLessonTitles: const ['Sandhi rules'],
      );
      final persona = pipeline.buildPersonaPrompt(ConversationContext(
        conversationId: 'c1',
        learner: const LearnerContext(companionName: 'Van'),
        messages: const [],
        learningContext: lc,
      ));
      // The fragment must reach the FINAL persona text — the prompt the
      // adapters actually receive — not merely exist on the context.
      expect(persona, contains(lc.fragment));
      expect(persona, contains('3 of 13 lessons'));
      expect(persona, contains('Sandhi rules'));
    });

    test('no learning context means no injected section', () {
      final persona = pipeline.buildPersonaPrompt(const ConversationContext(
        conversationId: 'c1',
        learner: LearnerContext(),
        messages: [],
      ));
      expect(persona, isNot(contains('LEARNING CONTEXT')));
    });
  });

  // -------------------------------------------------------------------------
  // learningContextProvider derives from REAL persisted state
  // -------------------------------------------------------------------------

  group('learningContextProvider (real providers, seeded storage)', () {
    Future<ProviderContainer> makeContainer(Map<String, Object> seed) async {
      dotenv.testLoad();
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      // Let the REAL curriculum asset load settle (plain test zone).
      await container.read(curriculumProvider.future);
      return container;
    }

    /// First touch constructs UserProfileNotifier (fire-and-forget load);
    /// pump microtasks so the load lands, mirroring production's reactive
    /// rebuild when the same state change arrives.
    Future<void> settleProfile(ProviderContainer container) async {
      container.read(userProfileProvider);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('fresh learner fragment names the first lesson as the next step',
        () async {
      final container = await makeContainer(<String, Object>{});
      addTearDown(container.dispose);
      await settleProfile(container);
      final lc = container.read(learningContextProvider);
      expect(lc.lessonsTotal, greaterThan(0));
      expect(lc.lessonsCompleted, 0);
      expect(lc.nextActionLabel, 'Start Learning');
      expect(lc.currentLessonTitle, isNotNull);
      final f = lc.fragment;
      expect(f, contains('Suggested next step: Start Learning'));
    });

    test('part-way learner fragment surfaces practice + weak areas + streak',
        () async {
      final container = await makeContainer(<String, Object>{
        AppConstants.keyCompletedLessonIds: <String>['ls_alphabet_vowels'],
        AppConstants.keyCurrentStreak: 3,
      });
      addTearDown(container.dispose);
      await settleProfile(container);
      final lc = container.read(learningContextProvider);
      expect(lc.lessonsCompleted, 1);
      expect(lc.currentStreak, 3);
      expect(lc.nextActionLabel, contains('Practice'));
      expect(lc.weakLessonTitles.single, contains('Vowels'));
      expect(lc.currentChapterTitle, isNotNull);
      final f = lc.fragment;
      expect(f, contains('1 of'));
      expect(f, contains('Day streak: 3'));
      expect(f, contains('Topics to revisit:'));
    });

    test('fragment is bounded even for a fully-completed curriculum',
        () async {
      final container = await makeContainer(<String, Object>{
        AppConstants.keyCompletedLessonIds: <String>[
          'ls_alphabet_vowels',
          'ls_alphabet_consonants',
          'ls_alphabet_barakhadi',
          'ls_alphabet_conjuncts',
          'ls_words_greetings',
          'ls_words_family',
          'ls_words_numbers',
          'ls_sentences_intro',
          'ls_sentences_questions',
          'ls_sentences_translation',
          'ls_grammar_nouns_cases',
          'ls_grammar_pronouns',
          'ls_grammar_verbs',
        ],
      });
      addTearDown(container.dispose);
      await settleProfile(container);
      final lc = container.read(learningContextProvider);
      expect(
          lc.weakLessonTitles.length, lessThanOrEqualTo(maxWeakTitlesInContext));
      expect(lc.fragment.length, lessThanOrEqualTo(maxFragmentLength));
    });
  });

  // -------------------------------------------------------------------------
  // Pipeline travel: ChatController → ConversationPipelineImpl → AI adapter
  // -------------------------------------------------------------------------

  group('pipeline travel (ChatController → ConversationPipelineImpl → AI)',
      () {
    test('ChatController stamps learningContextProvider output onto the '
        'context it hands the pipeline', () async {
      dotenv.testLoad();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      ConversationContext? seen;
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
        conversationPipelineProvider
            .overrideWithValue(_StubPipeline(onSend: (c) => seen = c)),
      ]);
      addTearDown(container.dispose);

      // Wait for the real curriculum to load so the context snapshot has
      // lesson totals (production rebuilds reactively on the same event).
      await container.read(curriculumProvider.future);

      await container.read(chatControllerProvider.notifier).sendMessage('hi');
      expect(seen, isNotNull);
      // Fresh learner with the real curriculum → startJourney stamp.
      expect(seen!.learningContext.lessonsTotal, greaterThan(0));
      expect(seen!.learningContextFragment,
          contains('Suggested next step: Start Learning'));
    });

    test('ConversationPipelineImpl builds the persona from the fragment and '
        'the adapter sees both', () async {
      final service = _CapturingService();
      final pipeline = ConversationPipelineImpl(
        aiService: service,
        promptPipeline: const DefaultPromptPipeline(),
        memory: _MemoryStub(),
        safetyFilter: const DefaultSafetyFilter(),
      );
      final lc = LearningContext.bounded(
        currentChapterTitle: 'Devanagari Basics',
        nextActionLabel: 'Practice: Vowel matras',
      );
      final result = await pipeline.send(
        context: ConversationContext(
          conversationId: 'c1',
          learner: const LearnerContext(companionName: 'Van'),
          messages: const [],
          learningContext: lc,
        ),
        userMessage: AiMessage.user(id: 'u1', content: 'namaste'),
        config: const AiConfig(provider: AiProviderId.offline),
      );
      expect(result.isRight(), isTrue);
      final seen = service.lastContext!;
      // The persona the ADAPTER-visible context carries embeds the fragment.
      expect(seen.personaPrompt, contains(lc.fragment));
      expect(seen.learningContext, lc);
    });
  });
}
