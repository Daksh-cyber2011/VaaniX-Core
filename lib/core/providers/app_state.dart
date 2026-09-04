/// VaaniX Global App State
///
/// Centralizes global, cross-cutting app state that does not belong to
/// any single feature. The goal is to avoid prop-drilling and scattered
/// top-level state through the widget tree.
///
/// Includes:
///   - Global loading overlay visibility (for full-screen blocking ops).
///   - Global in-app snackbar/notification queue.
///   - App initialization status (post-bootstrap).
///
/// Feature-specific state (auth, progress, etc.) lives in feature providers.
/// Network connectivity state lives in [connectivityStatusProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Global Loading Overlay ───────────────────────────────────────────────────

/// Whether a full-screen loading overlay should be shown.
///
/// Use sparingly — only for genuinely blocking operations that cannot show
/// progress inside a widget (e.g. account deletion, major data sync).
final globalLoadingProvider = StateProvider<bool>((_) => false);

// ─── App Initialization ───────────────────────────────────────────────────────

/// Enum representing the high-level initialization state of the app.
enum AppInitStatus {
  /// Bootstrap is running (before main completes).
  initializing,

  /// Bootstrap completed successfully.
  ready,

  /// Bootstrap failed with an unrecoverable error.
  failed,
}

/// Provider tracking whether the app has finished its bootstrap sequence.
///
/// Set to [AppInitStatus.ready] by the bootstrap layer once all startup
/// work is complete. Widgets that need to ensure bootstrap is done can
/// watch this provider.
final appInitStatusProvider = StateProvider<AppInitStatus>(
  (_) => AppInitStatus.ready,
);

// ─── Feature Flags ────────────────────────────────────────────────────────────

/// Simple, local feature flags for gating unfinished features.
///
/// When the remote config / feature-flag service is added, these will
/// be replaced by a remote provider while keeping the same API surface.
abstract final class FeatureFlags {
  /// Learn mode screens are accessible.
  static const bool learnModeEnabled = false;

  /// Exam mode screens are accessible.
  static const bool examModeEnabled = false;

  /// Progress analytics dashboard is accessible.
  static const bool progressEnabled = false;

  /// Van profile customization is accessible.
  static const bool vanProfileEnabled = false;

  /// Realtime sync with Supabase Realtime is active.
  static const bool realtimeSyncEnabled = false;

  /// Offline mode with local caching is active.
  static const bool offlineModeEnabled = false;

  /// Push notifications are enabled.
  static const bool notificationsEnabled = false;

  /// Localization (EN/HI) toggle is accessible in Settings.
  static const bool localizationEnabled = false;
}
