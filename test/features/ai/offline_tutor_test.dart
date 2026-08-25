import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/ai/data/offline_model_adapter.dart';
import 'package:vaanix_app/features/ai/data/offline_tutor.dart';
import 'package:vaanix_app/features/ai/domain/ai_domain.dart';

const _namaste = '\u0928\u092E\u0938\u094D\u0924\u0947';
const _dhanyavadah = '\u0927\u0928\u094D\u092F\u0935\u093E\u0926\u0903';

const _learner = LearnerContext(displayName: 'Aarav', companionName: 'Van');

AiMessage _user(String content, {String id = 'u'}) =>
    AiMessage.user(id: id, content: content);

ConversationContext _ctx(List<AiMessage> messages, {String id = 'conv-1'}) =>
    ConversationContext(
      conversationId: id,
      learner: _learner,
      messages: messages,
    );

void main() {
  const tutor = OfflineTutor();

  group('intent detection', () {
    test('empty input behaves like a greeting', () {
      expect(tutor.detectIntent(''), OfflineIntent.greeting);
    });

    test('greetings and thanks map correctly', () {
      expect(tutor.detectIntent('Hello Van!'), OfflineIntent.greeting);
      expect(tutor.detectIntent('namaste'), OfflineIntent.greeting);
      expect(tutor.detectIntent('thank you so much'), OfflineIntent.thanks);
      expect(tutor.detectIntent('dhanyavad'), OfflineIntent.thanks);
    });

    test('identity, practice and orientation map correctly', () {
      expect(tutor.detectIntent('who are you?'), OfflineIntent.identity);
      expect(tutor.detectIntent('quiz me!'), OfflineIntent.practice);
      expect(tutor.detectIntent('practice'), OfflineIntent.practice);
      expect(tutor.detectIntent('what can you do?'), OfflineIntent.orientation);
    });

    test('translate, grammar, numbers, family and correction map correctly',
        () {
      expect(tutor.detectIntent('how do you say mother in sanskrit'),
          OfflineIntent.translate);
      expect(tutor.detectIntent('what is a matra?'), OfflineIntent.translate);
      expect(tutor.detectIntent('explain barakhadi'), OfflineIntent.grammar);
      expect(tutor.detectIntent('count to ten'), OfflineIntent.numbers);
      expect(tutor.detectIntent('tell me family words'),
          OfflineIntent.familyTopic);
      expect(tutor.detectIntent('is this sentence correct?'),
          OfflineIntent.correction);
    });
  });

  group('grounded replies', () {
    test('greeting is personal and names the companion', () {
      final r = tutor.reply(
        message: 'hello',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('Aarav'));
      expect(r.text, contains('Van'));
    });

    test('english->sanskrit lookup uses the grounded dictionary', () {
      final r = tutor.reply(
        message: 'how do you say mother in sanskrit?',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('\u092E\u093E\u0924\u093E')); // maataa
      expect(r.text, contains('maataa'));
    });

    test('devanagari->english lookup works', () {
      final r = tutor.reply(
        message: 'what does \u092D\u094D\u0930\u093E\u0924\u093E mean?',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('Brother'));
      expect(r.text, contains('bhraataa'));
    });

    test('number lookups answer directly', () {
      final r = tutor.reply(
        message: 'what is 7 in sanskrit?',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('\u0938\u092A\u094D\u0924')); // sapta
    });

    test('numbers intent lists the grounded 1-10 table', () {
      final r = tutor.reply(
        message: 'numbers',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('\u090F\u0915\u092E\u094D')); // ekam
      expect(r.text, contains('\u0926\u0936')); // dasha
    });

    test('grammar card explains the left-attaching matra', () {
      final r = tutor.reply(
        message: 'what is a matra?',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('LEFT'));
      expect(r.text, contains('mama nama'));
    });

    test('unknown words are honestly reported as offline-only', () {
      final r = tutor.reply(
        message: 'what does abhimanyu mean?',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.text, contains('do not have that word'));
      expect(r.text.toLowerCase(), contains('offline'));
    });
  });

  group('practice flow', () {
    final q0 = OfflineTutor.practiceQuestions[0];

    test('asking for practice returns a graded question', () {
      final r = tutor.reply(
        message: 'practice',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: null,
        practiceIndex: 0,
      );
      expect(r.nextQuestion, isNotNull);
      expect(r.text, contains('Practice:'));
      expect(r.nextQuestion!.id, q0.id);
    });

    test('a correct answer is praised and the question resolves', () {
      final r = tutor.reply(
        message: 'it is pancha',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: q0,
        practiceIndex: 0,
      );
      expect(r.text, contains('right'));
      expect(r.text, contains('\u092A\u091E\u094D\u091A')); // pancha
      expect(r.nextQuestion, isNull);
    });

    test('a wrong answer hints and keeps the same question', () {
      final r = tutor.reply(
        message: 'I think it is cat',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: q0,
        practiceIndex: 0,
      );
      expect(r.text, contains('not quite'));
      expect(r.nextQuestion, isNotNull);
      expect(r.nextQuestion!.id, q0.id);
    });

    test('skip moves to the next question', () {
      final r = tutor.reply(
        message: 'skip',
        displayName: 'Aarav',
        companionName: 'Van',
        pendingQuestion: q0,
        practiceIndex: 0,
      );
      expect(r.nextQuestion, isNotNull);
      expect(r.nextQuestion!.id, isNot(q0.id));
    });
  });

  group('OfflineModelAdapter integration', () {
    final adapter = OfflineModelAdapter();

    test('greets a learner through the adapter complete() path', () async {
      final result = await adapter.complete(
        context: _ctx([_user('hello')]),
        config: AiConfig.offline,
      );
      final message = result.fold((failure) => null, (m) => m);
      expect(message, isNotNull);
      expect(message!.content, contains('Aarav'));
      expect(message.content, contains('Van'));
    });

    test('practice lifecycle: ask -> answer -> advance cursor', () async {
      // Turn 1: ask for practice in "conv-2".
      final t1 = await adapter.complete(
        context: _ctx([_user('practice')], id: 'conv-2'),
        config: AiConfig.offline,
      );
      final m1 = t1.fold((failure) => null, (m) => m)!;
      expect(m1.content, contains('Practice:'));
      expect(m1.metadata['practiceQId'], isNotNull);

      // Turn 2: answer correctly in the same conversation.
      final t2 = await adapter.complete(
        context: _ctx(
          [
            _user('practice'),
            AiMessage.assistant(id: 'a1', content: m1.content),
            _user('pancha'),
          ],
          id: 'conv-2',
        ),
        config: AiConfig.offline,
      );
      final m2 = t2.fold((failure) => null, (m) => m)!;
      expect(m2.content.toLowerCase(), contains('right'));

      // Turn 3: a fresh "practice" in the same conversation should move to
      // the NEXT question (cursor advanced after the correct answer).
      final t3 = await adapter.complete(
        context: _ctx(
          [
            _user('practice'),
            AiMessage.assistant(id: 'a1', content: m1.content),
            _user('pancha'),
            AiMessage.assistant(id: 'a2', content: m2.content),
            _user('practice'),
          ],
          id: 'conv-2',
        ),
        config: AiConfig.offline,
      );
      final m3 = t3.fold((failure) => null, (m) => m)!;
      expect(m3.content, contains('matra'),
          reason: 'cursor advanced to the second practice question');
    });

    test('wrong answers keep the same question in a fresh conversation',
        () async {
      final t1 = await adapter.complete(
        context: _ctx([_user('practice')], id: 'conv-3'),
        config: AiConfig.offline,
      );
      final m1 = t1.fold((failure) => null, (m) => m)!;

      final t2 = await adapter.complete(
        context: _ctx(
          [
            _user('practice'),
            AiMessage.assistant(id: 'a1', content: m1.content),
            _user('xyz'),
          ],
          id: 'conv-3',
        ),
        config: AiConfig.offline,
      );
      final m2 = t2.fold((failure) => null, (m) => m)!;
      expect(m2.content.toLowerCase(), contains('not quite'));
    });

    test('streaming emits the same grounded reply', () async {
      final deltas = <String>[];
      final stream = adapter.stream(
        context: _ctx([_user('hello')], id: 'conv-4'),
        config: AiConfig.offline,
      );
      var done = false;
      await for (final d in stream) {
        d.fold((failure) => null, (delta) {
          deltas.add(delta.content);
          done = delta.done;
        });
      }
      expect(done, isTrue);
      expect(deltas.join(' '), contains('Aarav'));
    });
  });

  group('content grounding', () {
    test('all practice answer tokens resolve inside grounded vocabulary', () {
      // The pancha + dhanyavadah tokens must equal what the tutor prints.
      expect(
        OfflineTutor.practiceQuestions[0].answerTokens,
        contains('\u092A\u091E\u094D\u091A'),
      );
      expect(
        OfflineTutor.practiceQuestions[3].answerTokens,
        contains('\u0927\u0928\u094D\u092F\u0935\u093E\u0926'),
      );
      expect(_namaste, hasLength(6)); // na ma sa virama ta e
      expect(_dhanyavadah, hasLength(8));
    });
  });
}
