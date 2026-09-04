/// VaaniX Authentication Domain
///
/// Domain-layer models for authentication. These are pure, framework-free
/// value objects. Supabase types are mapped into them at the repository
/// boundary so the rest of the app depends only on VaaniX-owned types.

import 'package:equatable/equatable.dart';

/// The current authentication status of the user.
enum AuthStatus {
  /// No session and no in-flight auth operation.
  unauthenticated,

  /// A session exists and is valid.
  authenticated,

  /// Session exists but the token is no longer valid and refresh failed.
  sessionExpired,
}

/// A minimal, framework-agnostic view of the signed-in user.
///
/// Kept intentionally small — feature-specific profile data lives in its
/// own domain models, not here.
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
  static const AuthSession empty = AuthSession(status: AuthStatus.unauthenticated);

  @override
  List<Object?> get props => [status, user, accessToken, expiresAt];
}
