/// VaaniX Core Auth Session Domain Models
///
/// Core-level value objects for authentication and session management.
/// Placing these in `core/auth/` ensures `core` infrastructure components
/// (e.g. [SessionManager], router guards) can depend on auth concepts
/// without violating Clean Architecture layer boundaries (core -> features).

import 'package:equatable/equatable.dart';

/// Authentication status of the current user session.
enum AuthStatus {
  /// No session and no in-flight auth operation.
  unauthenticated,

  /// A session exists and is valid.
  authenticated,

  /// Session exists but the token is no longer valid and refresh failed.
  sessionExpired,
}

/// A minimal, framework-agnostic view of the signed-in user.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.phone,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? photoUrl;

  @override
  List<Object?> get props => [id, email, phone, displayName, photoUrl];
}

/// Immutable snapshot of the current authentication state.
class AuthSession extends Equatable {
  const AuthSession({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// A session with no user, used as the initial / signed-out state.
  static const AuthSession empty =
      AuthSession(status: AuthStatus.unauthenticated);

  @override
  List<Object?> get props => [status, user, accessToken, expiresAt];
}
