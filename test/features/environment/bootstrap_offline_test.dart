/// Offline Bootstrap Tests
///
/// Proves the real production startup path completes with NO .env file
/// bundled (the shipped assets/env/ contains only .gitkeep): the app must
/// boot fully offline - unconfigured Supabase/Gemini, development flavor -
/// instead of crashing with dotenv's NotInitializedError.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/app/bootstrap/app_bootstrap.dart';
import 'package:vaanix_app/core/environment/app_environment.dart';

/// Builds the ByteData response the asset channel expects.
ByteData? _assetResponse(String? content) {
  if (content == null) return null;
  return ByteData.view(
    Uint8List.fromList(utf8.encode(content)).buffer,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ensure the env asset is genuinely absent from the test bundle, matching
  // the shipped artifact (assets/env/ has no .env).
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      return null;
    });
  });

  test('bootstrap completes without a .env file (offline startup)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final result = await bootstrap();

    expect(result.sharedPreferences, isNotNull);
    expect(AppEnvironment.isSupabaseConfigured, isFalse,
        reason: 'no credentials -> Noop auth path');
    expect(AppEnvironment.isGeminiConfigured, isFalse,
        reason: 'no key -> offline AI adapter');
    expect(AppEnvironment.flavor.name, 'development');
    // dotenv reads stay safe after the fallback initialization.
    expect(dotenv.env['ANY_KEY'], isNull);
  });

  test('a malformed .env also degrades to a safe empty environment', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Malformed content: dotenv.load throws, bootstrap must still complete
    // through the empty-env fallback.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      if (message?.buffer.asUint8List() != null &&
          utf8.decode(message!.buffer.asUint8List()) == 'assets/env/.env') {
        return _assetResponse('::not valid env content::');
      }
      return null;
    });

    final result = await bootstrap();

    expect(result.sharedPreferences, isNotNull);
    expect(AppEnvironment.isSupabaseConfigured, isFalse);
    expect(AppEnvironment.isGeminiConfigured, isFalse);
  });
}
