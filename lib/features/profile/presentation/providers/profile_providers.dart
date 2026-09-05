/// Profile Providers — Riverpod wiring
///
/// Exposes the [UserProfileRepository] and a reactive [UserProfileNotifier]
/// that holds the current [UserProfile] in memory and persists every change.
///
/// Segment 5: [UserProfileNotifier] now reads the auth session to populate
/// [UserProfile.id] and [UserProfile.isAnonymous]. When the session changes
/// (sign-in / sign-out), the profile is re-loaded with the updated identity.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/analytics/analytics_client.dart';
import 'package:vaanix_app/core/analytics/analytics_event.dart';
import 'package:vaanix_app/core/analytics/analytics_provider.dart';
import 'package:vaanix_app/core/auth/core_auth_session.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/profile/data/local_user_profile_repository.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';

/// The active [UserProfileRepository]. Defaults to the local-first impl;
/// override in tests or when a remote backend is configured.
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return LocalUserProfileRepository(ref.watch(localStorageServiceProvider));
});

/// Reactive holder of the learner's [UserProfile].
///
/// Watches [latestAuthSessionProvider] so that sign-in / sign-out events
/// automatically update [UserProfile.id] and [UserProfile.isAnonymous]
/// without requiring a manual refresh.
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier(this._repo, this._session, this._analytics)
      : super(UserProfile.empty) {
    _load();
  }

  final UserProfileRepository _repo;
  final AuthSession _session;
  final AnalyticsClient _analytics;

  Future<void> _load() async {
    final result = await _repo.getProfile();
    // The constructor fires this unawaited; the provider element may have
    // been disposed while the read was in flight (app teardown, reset).
    if (!mounted) return;
    result.fold(
      (_) {}, // keep empty defaults on failure
      (profile) {
        // Populate identity fields from the current auth session.
        // This ensures isAnonymous and id are always accurate, even
        // when the local profile was loaded before sign-in completed.
        state = profile.copyWith(
          id: _session.user?.id,
          isAnonymous: _session.user == null,
        );
      },
    );
  }

  /// Set the learner's own name (AI personalization). Empty string clears
  /// it — Van returns to addressing the learner without a name.
  Future<void> updateDisplayName(String name) async {
    state = state.copyWith(displayName: name.trim());
    await _repo.updateDisplayName(name);
  }

  Future<void> updateCompanionName(String name) async {
    state = state.copyWith(companionName: name);
    await _repo.updateCompanionName(name);
  }

  Future<void> updatePersonalityMode(PersonalityMode mode) async {
    state = state.copyWith(personalityMode: mode);
    await _repo.updatePersonalityMode(mode);
  }

  /// Clears Van's personality mode — the true "reset to default". The
  /// state is rebuilt explicitly (copyWith cannot null a field out) so
  /// the Van Profile screen returns to its generic greeting and Settings
  /// shows "Not set".
  Future<void> clearPersonalityMode() async {
    state = UserProfile(
      id: state.id,
      displayName: state.displayName,
      companionName: state.companionName,
      personalityMode: null,
      cbseClass: state.cbseClass,
      dailyGoalMinutes: state.dailyGoalMinutes,
      currentStreak: state.currentStreak,
      lastActiveDate: state.lastActiveDate,
      isAnonymous: state.isAnonymous,
    );
    await _repo.clearPersonalityMode();
  }

  Future<void> updateCbseClass(CbseClass? cbseClass) async {
    state = state.copyWith(cbseClass: cbseClass);
    await _repo.updateCbseClass(cbseClass);
  }

  Future<void> updateDailyGoal(int minutes) async {
    state = state.copyWith(dailyGoalMinutes: minutes);
    await _repo.updateDailyGoal(minutes);
  }

  /// Record today's activity and return the new streak.
  Future<int> recordDailyActivity() async {
    final result = await _repo.recordDailyActivity();
    // Only mutate state on a persisted success: the previous version
    // stamped lastActiveDate = today even when the repository write
    // failed, desyncing the in-memory streak window from storage.
    var nextStreak = state.currentStreak;
    var succeeded = false;
    result.fold((_) {}, (v) {
      nextStreak = v;
      succeeded = true;
    });
    if (!succeeded) return nextStreak;

    final extended = nextStreak > state.currentStreak;
    state = state.copyWith(
      currentStreak: nextStreak,
      lastActiveDate: _todayIso(),
    );
    if (extended) {
      _analytics.log(const AnalyticsEvent(AnalyticsEventName.streakExtended));
    }
    return nextStreak;
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}'
        '-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  // Watch the auth session so the profile re-builds on sign-in / sign-out.
  // This populates UserProfile.id and isAnonymous from the live session.
  final session = ref.watch(latestAuthSessionProvider);
  return UserProfileNotifier(
    ref.watch(userProfileRepositoryProvider),
    session,
    ref.watch(analyticsClientProvider),
  );
});
