/// VaaniX Local Storage Service
///
/// Lightweight JSON cache built on top of [SharedPreferences] string slots.
/// Used by repository layers to persist a last-known snapshot of remote data
/// so the UI can render instantly offline while a refresh runs in the
/// background.
///
/// Not for sensitive data — use [SecureStorageService] for that.
/// Not for app settings — use [PreferencesService] for that.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../errors/exceptions.dart';
import 'logger_service.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  /// Reads and JSON-decodes the value at [key].
  /// Returns `null` when the key is absent.
  /// Throws [CacheException] on decode failure (corrupted cache).
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (e, st) {
      AppLogger.w('Corrupted cache at "$key" — discarding', e, st);
      await _prefs.remove(key);
      throw const CacheException('Corrupted local cache entry');
    }
  }

  /// Reads and JSON-decodes a list value at [key].
  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } on FormatException catch (e, st) {
      AppLogger.w('Corrupted cache list at "$key" — discarding', e, st);
      await _prefs.remove(key);
      throw const CacheException('Corrupted local cache entry');
    }
  }

  /// JSON-encodes [value] and writes it to [key].
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    try {
      await _prefs.setString(key, jsonEncode(value));
    } on Exception catch (e, st) {
      AppLogger.w('Cache write failed at "$key"', e, st);
      throw const CacheException('Failed to write local cache');
    }
  }

  Future<void> writeJsonList(String key, List<Map<String, dynamic>> value) async {
    try {
      await _prefs.setString(key, jsonEncode(value));
    } on Exception catch (e, st) {
      AppLogger.w('Cache list write failed at "$key"', e, st);
      throw const CacheException('Failed to write local cache');
    }
  }

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearWithPrefix(String prefix) async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
