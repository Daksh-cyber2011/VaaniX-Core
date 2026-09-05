/// VaaniX Core Infrastructure Barrel Export
///
/// Single entry point for all cross-cutting core infrastructure. Features and
/// the app layer import from here (or from the specific files) to reach theme,
/// constants, errors, network, storage, auth contracts, logging, navigation,
/// lifecycle, and providers.
///
/// Dependency rule: `core` MUST NOT import from `features` or `app`.
/// `core` owns only abstractions and infrastructure; it never knows which
/// feature or screen consumes it.
library;

// ─── Auth contracts (abstractions consumed by features) ─────────────────────
export 'auth/core_auth_repository.dart';
export 'auth/core_auth_session.dart';

// ─── Constants & environment ────────────────────────────────────────────────
export 'constants/app_constants.dart';
export 'constants/route_names.dart';
export 'environment/app_environment.dart';

// ─── Errors & result types ──────────────────────────────────────────────────
export 'errors/app_error_handler.dart';
export 'errors/exception_mapper.dart';
export 'errors/exceptions.dart';
export 'errors/failures.dart';
export 'utils/result.dart';

// ─── Network & connectivity ─────────────────────────────────────────────────
// The HTTP transport lives inside the AI adapter layer (google_generative_ai)
// and Supabase's own client; the former standalone Dio stack was removed in
// Phase 6 as dead infrastructure. Connectivity awareness remains here.
export 'network/connectivity_service.dart';

// ─── Storage & Supabase infrastructure ──────────────────────────────────────
export 'storage/i_local_storage_service.dart';
export 'storage/local_storage_service.dart';
export 'supabase/supabase_config.dart';

// ─── Logging & lifecycle ────────────────────────────────────────────────────
export 'logging/logger.dart';
export 'lifecycle/app_lifecycle_observer.dart';

// ─── Navigation ─────────────────────────────────────────────────────────────
export 'navigation/navigator_keys.dart';
// NavigationService was removed in Phase 6: nothing ever watched its
// provider. navigator_keys.dart remains — the router owns rootNavigatorKey.

// ─── Theme ──────────────────────────────────────────────────────────────────
export 'theme/app_colors.dart';
export 'theme/app_text_styles.dart';
export 'theme/app_theme.dart';
export 'theme/theme_notifier.dart';

// ─── Core providers (state management wiring) ───────────────────────────────
export 'providers/app_providers.dart';
// providers/app_state.dart (globalLoading / appInitStatus / FeatureFlags —
// never consumed anywhere) was removed in Phase 6.
export 'providers/session_manager.dart';
