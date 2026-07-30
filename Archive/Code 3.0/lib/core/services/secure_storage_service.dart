/// VaaniX Secure Storage Service
///
/// Wraps [FlutterSecureStorage] for sensitive key/value pairs (session
/// markers, refresh hints). Access tokens themselves are managed by the
/// Supabase SDK; this service stores lightweight companion metadata only.
///
/// All methods are async and swallow nothing — callers handle errors.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'logger_service.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  /// Marker written after the first successful sign-in. Used to decide
  /// whether to attempt a silent session restore on cold start.
  Future<bool> getHasSession() async {
    try {
      final value = await _storage.read(key: AppConstants.secureHasSession);
      return value == '1';
    } on Exception catch (e, st) {
      AppLogger.w('SecureStorage read hasSession failed', e, st);
      return false;
    }
  }

  Future<void> setHasSession(bool value) async {
    try {
      await _storage.write(
        key: AppConstants.secureHasSession,
        value: value ? '1' : '0',
      );
    } on Exception catch (e, st) {
      AppLogger.w('SecureStorage write hasSession failed', e, st);
    }
  }

  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } on Exception catch (e, st) {
      AppLogger.w('SecureStorage clear failed', e, st);
    }
  }
}
