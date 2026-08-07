/// Profile Providers — Riverpod wiring
///
/// Exposes the [UserProfileRepository] and a reactive [UserProfileNotifier]
/// that holds the current [UserProfile] in memory and persists every change.
///
/// Segment 5: [UserProfileNotifier] now reads the auth session to populate
/// [UserProfile.id] and [UserProfile.isAnonymous]. When the session changes
/// (sign-in / sign-out), the profile is re-loaded with the updated identity.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  UserProfileNotifier(this._repo, this._session) : super(UserProfile.empty) {
    _load();
  }

  final UserProfileRepository _repo;
  final AuthSession _session;

  Future<void> _load() async {
    final result = await _repo.getProfile();
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

  Future<void> updateCompanionName(String name) async {
    state = state.copyWith(companionName: name);
    await _repo.updateCompanionName(name);
  }

  Future<void> updatePersonalityMode(PersonalityMode mode) async {
    state = state.copyWith(personalityMode: mode);
    await _repo.updatePersonalityMode(mode);
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
    final next = result.fold((_) => state.currentStreak, (v) => v);
    state = state.copyWith(
      currentStreak: next,
      lastActiveDate: _todayIso(),
    );
    return next;
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
  );
});
