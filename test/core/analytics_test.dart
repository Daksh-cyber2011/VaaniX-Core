/// Analytics Abstraction Tests (V1 §5)
///
/// Proves:
///   - the typed event vocabulary is closed and bounded (payload caps),
///   - the production default client is a true no-op,
///   - logging never throws — even after container disposal,
///   - REAL flows emit REAL events (lesson completion, onboarding,
///     theme change, chat send) via a capturing client override.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/core/theme/theme_notifier.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/ai/domain/ai_config.dart';
import 'package:vaanix_app/features/ai/domain/ai_message.dart';
import 'package:vaanix_app/features/ai/domain/conversation_context.dart';
import 'package:vaanix_app/features/ai/domain/conversation_pipeline.dart';
import 'package:vaanix_app/features/ai/presentation/providers/ai_providers.dart';
import 'package:vaanix_app/features/ai/presentation/providers/chat_controller.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/presentation/providers/progress_providers.dart';

/// Capturing client: records every event without external dependencies.
class CapturingAnalyticsClient implements AnalyticsClient {
  final List<AnalyticsEvent> events = [];

  @override
  void log(AnalyticsEvent event) => events.add(event);
}

/// Pipeline stub: echoes the context back so ChatController completes.
class _EchoPipeline implements ConversationPipeline {
  @override
  Future<Result<ConversationContext>> send({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) async =>
      ok(context.append(AiMessage.assistant(id: 'a', content: 'reply')));

  @override
  Stream<Result<AiStreamDelta>> stream({
    required ConversationContext context,
    required AiMessage userMessage,
    AiConfig config = const AiConfig(),
  }) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsEvent bounds', () {
    test('event names are the closed V1 vocabulary (17 events)', () {
      expect(AnalyticsEventName.values.length, 17);
      // Ids are stable lowercase strings.
      for (final name in AnalyticsEventName.values) {
        expect(name.id, name.name);
      }
    });

    test('bounded factory caps payload entries', () {
      final event = AnalyticsEvent.bounded(
        AnalyticsEventName.settingsChanged,
        {
          for (var i = 0; i < 20; i++) 'field$i': 'value$i',
        },
      );
      expect(event.payload.length, maxPayloadEntries);
    });

    test('bounded factory truncates over-long string values', () {
      final event = AnalyticsEvent.bounded(
        AnalyticsEventName.appErrorRecovered,
        {'detail': 'x' * 500},
      );
      expect(
        (event.payload['detail'] as String).length,
        maxPayloadValueLength,
      );
    });

    test('plain constructor accepts payload as-is (trusted internal sites)',
        () {
      const event = AnalyticsEvent(
        AnalyticsEventName.lessonCompleted,
        {'lessonId': 'ls_1', 'xp': 20},
      );
      expect(event.payload['lessonId'], 'ls_1');
    });
  });

  group('Clients', () {
    test('NoopAnalyticsClient discards silently (production default)', () {
      // Must not throw and must not retain anything.
      const NoopAnalyticsClient().log(const AnalyticsEvent(
        AnalyticsEventName.appOpened,
      ));
      expect(const NoopAnalyticsClient(), isA<AnalyticsClient>());
    });

    test('ref.log after container disposal never throws (guard contract)',
        () async {
      dotenv.testLoad();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      Ref? captured;
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      // A provider whose Ref escapes to the test — mirrors a StateNotifier
      // logging from an async callback after the app tore down.
      final refCaptor = Provider<void>((ref) => captured = ref);
      container.read(refCaptor);
      container.dispose();

      expect(captured, isNotNull);
      // Raw reads DO throw (Riverpod contract) ...
      expect(() => captured!.read(analyticsClientProvider), throwsStateError);
      // ... but the ref.log extension swallows them: analytics must never
      // crash the app, no matter when it fires.
      expect(
        () => captured!
            .log(const AnalyticsEvent(AnalyticsEventName.appOpened)),
        returnsNormally,
      );
    });
  });

  group('Real flows emit real events', () {
    late CapturingAnalyticsClient client;
    late ProviderContainer container;

    setUp(() async {
      dotenv.testLoad();
      client = CapturingAnalyticsClient();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
        analyticsClientProvider.overrideWithValue(client),
      ]);
    });

    tearDown(() => container.dispose());

    test('appOpened fires exactly once per container at the app root',
        () async {
      container.read(appOpenedEventProvider);
      container.read(appOpenedEventProvider); // cached — no second event
      expect(
        client.events.map((e) => e.name).toList(),
        [AnalyticsEventName.appOpened],
      );
    });

    test('completing a lesson emits lessonCompleted with id + XP', () async {
      await container.read(completedLessonIdsProvider.notifier).markComplete(
            const Lesson(
              id: 'ls_analytics',
              chapterId: 'ch_x',
              title: 'Analytics Lesson',
              xpReward: 15,
            ),
          );
      expect(client.events.map((e) => e.name),
          contains(AnalyticsEventName.lessonCompleted));
      final event = client.events
          .firstWhere((e) => e.name == AnalyticsEventName.lessonCompleted);
      expect(event.payload['lessonId'], 'ls_analytics');
      expect(event.payload['xp'], 15);
    });

    test('completing onboarding emits onboardingCompleted', () async {
      await container.read(onboardingProvider.notifier).completeOnboarding();
      expect(client.events.map((e) => e.name),
          contains(AnalyticsEventName.onboardingCompleted));
    });

    test('changing the theme emits themeChanged with the mode', () async {
      await container
          .read(themeNotifierProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      final event = client.events
          .firstWhere((e) => e.name == AnalyticsEventName.themeChanged);
      expect(event.payload['mode'], 'dark');
    });

    test('a chat send emits aiConversationStarted + aiMessageSent '
        '(stubbed pipeline so no real AI runs)', () async {
      final chatContainer = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(
          (await SharedPreferences.getInstance()),
        ),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
        analyticsClientProvider.overrideWithValue(client),
        conversationPipelineProvider.overrideWithValue(_EchoPipeline()),
      ]);
      addTearDown(chatContainer.dispose);
      await chatContainer
          .read(chatControllerProvider.notifier)
          .sendMessage('namaste');
      expect(client.events.map((e) => e.name),
          containsAll(<AnalyticsEventName>[
            AnalyticsEventName.aiMessageSent,
            AnalyticsEventName.aiConversationStarted,
          ]));
    });
  });
}
