/// VaaniX AI — Token Usage Tracker
///
/// Tracks daily AI usage (requests, prompt tokens, completion tokens) so
/// the user can see how much of their free-tier quota they've consumed.
///
/// Gemini free-tier limits (as of 2024):
///   - 15 requests per minute (RPM)
///   - 1,500 requests per day (RPD)
///   - 1 million tokens per day
///
/// Usage is persisted to SharedPreferences as a JSON map keyed by date
/// string (YYYY-MM-DD). Each entry has:
///   {requestCount, promptTokens, completionTokens, totalTokens}
///
/// The tracker automatically rolls over at midnight — yesterday's usage
/// is preserved for history but today starts fresh.

import 'dart:convert';

import 'package:vaanix_app/core/storage/i_local_storage_service.dart';

class TokenUsageTracker {
  TokenUsageTracker(this._storage);

  final ILocalStorageService _storage;

  static const String _usageKey = 'ai_token_usage';

  /// Gemini free-tier daily limits.
  static const int dailyRequestLimit = 1500;
  static const int dailyTokenLimit = 1000000; // 1M tokens

  /// Today's date as a normalized string (YYYY-MM-DD, local time).
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  /// Record a completed API call's token usage.
  Future<void> recordUsage({
    required int promptTokens,
    required int completionTokens,
  }) async {
    final usage = await _loadAll();
    final today = _todayKey;

    final todayEntry = (usage[today] as Map<String, dynamic>?) ??
        {
          'requestCount': 0,
          'promptTokens': 0,
          'completionTokens': 0,
          'totalTokens': 0,
        };

    todayEntry['requestCount'] = (todayEntry['requestCount'] as int) + 1;
    todayEntry['promptTokens'] =
        (todayEntry['promptTokens'] as int) + promptTokens;
    todayEntry['completionTokens'] =
        (todayEntry['completionTokens'] as int) + completionTokens;
    todayEntry['totalTokens'] =
        (todayEntry['totalTokens'] as int) + promptTokens + completionTokens;

    usage[today] = todayEntry;
    await _storage.setString(_usageKey, jsonEncode(usage));
  }

  /// Get today's usage snapshot.
  Future<DailyUsage> getTodayUsage() async {
    final usage = await _loadAll();
    final today = _todayKey;
    final entry = usage[today] as Map<String, dynamic>?;

    if (entry == null) {
      return DailyUsage.zero();
    }

    return DailyUsage(
      requestCount: entry['requestCount'] as int? ?? 0,
      promptTokens: entry['promptTokens'] as int? ?? 0,
      completionTokens: entry['completionTokens'] as int? ?? 0,
      totalTokens: entry['totalTokens'] as int? ?? 0,
    );
  }

  /// Get usage for the last [days] days (for history display).
  Future<List<DailyUsageEntry>> getRecentHistory({int days = 7}) async {
    final usage = await _loadAll();
    final result = <DailyUsageEntry>[];

    for (var i = 0; i < days; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = '${date.year.toString().padLeft(4, '0')}'
          '-${date.month.toString().padLeft(2, '0')}'
          '-${date.day.toString().padLeft(2, '0')}';
      final entry = usage[key] as Map<String, dynamic>?;
      result.add(DailyUsageEntry(
        date: date,
        requestCount: entry?['requestCount'] as int? ?? 0,
        totalTokens: entry?['totalTokens'] as int? ?? 0,
      ));
    }

    return result;
  }

  /// Clear all usage history (used by Settings → reset).
  Future<void> clear() async {
    await _storage.setString(_usageKey, '{}');
  }

  /// Load the full usage map from storage.
  Future<Map<String, dynamic>> _loadAll() async {
    final raw = _storage.getString(_usageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Immutable snapshot of one day's AI usage.
class DailyUsage {
  const DailyUsage({
    required this.requestCount,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int requestCount;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  factory DailyUsage.zero() => const DailyUsage(
        requestCount: 0,
        promptTokens: 0,
        completionTokens: 0,
        totalTokens: 0,
      );

  /// Percentage of daily request limit used (0.0 – 1.0).
  double get requestUsageFraction =>
      requestCount / TokenUsageTracker.dailyRequestLimit;

  /// Percentage of daily token limit used (0.0 – 1.0).
  double get tokenUsageFraction =>
      totalTokens / TokenUsageTracker.dailyTokenLimit;

  /// Remaining requests for today.
  int get remainingRequests =>
      (TokenUsageTracker.dailyRequestLimit - requestCount)
          .clamp(0, TokenUsageTracker.dailyRequestLimit);
}

/// A single day's usage entry (for history display).
class DailyUsageEntry {
  const DailyUsageEntry({
    required this.date,
    required this.requestCount,
    required this.totalTokens,
  });

  final DateTime date;
  final int requestCount;
  final int totalTokens;
}
