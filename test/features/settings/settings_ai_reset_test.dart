/// Phase 4: Settings → Reset Progress clears the AI subsystem too (defect #9).
///
/// Before this phase a full reset left persisted AI conversations, the
/// response cache and the token-usage history behind — the tracker's
/// clear() even documented "used by Settings → reset" without ever being
/// called. This widget test drives the REAL reset flow and asserts every
/// AI-shaped key is gone while the learner's profile survives.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/settings/presentation/screens/settings_screen.dart';

void main() {
  testWidgets('reset clears AI conversations, response cache and usage stats',
      (tester) async {
    dotenv.testLoad();
    SharedPreferences.setMockInitialValues(<String, Object>{
      // Learner identity that must SURVIVE the reset.
      AppConstants.keyUserCompanionName: 'Mita',
      // A persisted chat transcript.
      '${AppConstants.aiConversationKeyPrefix}conv_1700000000000':
          jsonEncode([
        {'id': 'u1', 'role': 'user', 'content': 'namaste'},
        {'id': 'a1', 'role': 'assistant', 'content': 'Namaste!'},
      ]),
      // A cached Q&A entry.
      'ai_response_cache': jsonEncode({
        'what does namaste mean': {
          'answer': 'a greeting',
          'cachedAt': '2026-09-05T10:00:00.000Z',
        },
      }),
      // A usage-history day.
      'ai_token_usage': jsonEncode({
        '2026-09-05': {
          'requestCount': 3,
          'promptTokens': 120,
          'completionTokens': 300,
          'totalTokens': 420,
        },
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    // The settings list lazily builds its children — the Reset card sits
    // below the default 800×600 test viewport, so render a tall surface.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Drive the real reset flow: tap the Reset Progress card, confirm.
    await tester.tap(find.text('Reset Progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    // Every AI-shaped key is gone…
    expect(
      prefs.getString(
          '${AppConstants.aiConversationKeyPrefix}conv_1700000000000'),
      isNull,
      reason: 'persisted chat transcripts must not survive a full reset',
    );
    expect(prefs.getString('ai_response_cache'), '{}',
        reason: 'the response cache must be emptied');
    expect(prefs.getString('ai_token_usage'), '{}',
        reason: 'the token-usage history must be cleared (defect #9)');

    // …while the learner's identity survives the reset.
    expect(prefs.getString(AppConstants.keyUserCompanionName), 'Mita',
        reason: 'profile identity (companion name) is kept by design');
  });
}
