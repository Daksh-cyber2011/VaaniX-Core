/// VaaniX AI — Rate Limiter
///
/// Manages request timing to stay within Gemini's free-tier limits:
///   - 15 requests per minute (RPM)
///   - 1,500 requests per day (RPD)
///   - 1 million tokens per day
///
/// When the per-minute limit is approached, the limiter delays the next
/// request instead of firing it immediately. This prevents 429 errors and
/// gives the user a smooth "queued" experience rather than an error.
///
/// The limiter is intentionally simple — it tracks request timestamps in
/// memory (no persistence needed for per-minute tracking). Daily limits
/// are tracked by [TokenUsageTracker] which persists to SharedPreferences.

class AiRateLimiter {
  AiRateLimiter({
    this.maxRequestsPerMinute = 14, // stay 1 under the 15 RPM limit
    this.minDelayBetweenRequests = const Duration(milliseconds: 500),
  });

  /// Maximum requests allowed in a rolling 60-second window.
  /// Set to 14 (not 15) to leave headroom for clock drift.
  final int maxRequestsPerMinute;

  /// Minimum delay between consecutive requests. Prevents burst-firing
  /// that could trigger Google's abuse detection.
  final Duration minDelayBetweenRequests;

  /// Timestamps of requests in the current 60-second window.
  final List<DateTime> _recentRequests = [];

  /// Timestamp of the last request (for min-delay enforcement).
  DateTime? _lastRequestTime;

  /// Returns the delay (if any) before the next request can be sent.
  /// Returns [Duration.zero] if the request can fire immediately.
  Duration get nextAvailableDelay {
    final now = DateTime.now();

    // 1. Enforce minimum delay between requests.
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      if (elapsed < minDelayBetweenRequests) {
        return minDelayBetweenRequests - elapsed;
      }
    }

    // 2. Prune timestamps older than 60 seconds.
    _recentRequests.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 60),
    );

    // 3. If at capacity, wait until the oldest request exits the window.
    if (_recentRequests.length >= maxRequestsPerMinute) {
      final oldest = _recentRequests.first;
      final waitUntil = oldest.add(const Duration(seconds: 60));
      return waitUntil.difference(now);
    }

    return Duration.zero;
  }

  /// Returns true if the limiter currently has capacity to send a request
  /// immediately (no delay needed).
  bool get canSendNow => nextAvailableDelay == Duration.zero;

  /// Records that a request was sent. Call this right before sending.
  void recordRequest() {
    final now = DateTime.now();
    _recentRequests.add(now);
    _lastRequestTime = now;
  }

  /// Waits for the appropriate delay, then calls [recordRequest].
  /// Use this before every API call to automatically throttle.
  Future<void> awaitSlot() async {
    final delay = nextAvailableDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    recordRequest();
  }

  /// Number of requests in the current 60-second window (for UI display).
  int get currentMinuteCount {
    final now = DateTime.now();
    _recentRequests.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 60),
    );
    return _recentRequests.length;
  }
}
