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
export 'network/connectivity_service.dart';
export 'network/dio_client.dart';
export 'network/interceptors/auth_interceptor.dart';
export 'network/interceptors/logging_interceptor.dart';
export 'network/interceptors/retry_interceptor.dart';

// ─── Storage & Supabase infrastructure ──────────────────────────────────────
export 'storage/i_local_storage_service.dart';
export 'storage/local_storage_service.dart';
export 'supabase/supabase_config.dart';

// ─── Logging & lifecycle ────────────────────────────────────────────────────
export 'logging/logger.dart';
export 'lifecycle/app_lifecycle_observer.dart';

// ─── Navigation ─────────────────────────────────────────────────────────────
export 'navigation/navigation_service.dart';

// ─── Theme ──────────────────────────────────────────────────────────────────
export 'theme/app_colors.dart';
export 'theme/app_text_styles.dart';
export 'theme/app_theme.dart';
export 'theme/theme_notifier.dart';

// ─── Core providers (state management wiring) ───────────────────────────────
export 'providers/app_providers.dart';
export 'providers/app_state.dart';
export 'providers/session_manager.dart';
