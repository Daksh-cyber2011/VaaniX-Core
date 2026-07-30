/// Profile Providers — Riverpod wiring
///
/// Exposes the [UserProfileRepository] and a reactive [UserProfileNotifier]
/// that holds the current [UserProfile] in memory and persists every change.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/profile/data/local_user_profile_repository.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';

/// The active [UserProfileRepository]. Defaults to the local-first impl;
/// override in tests or when a remote backend is configured.
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return LocalUserProfileRepository(ref.watch(localStorageServiceProvider));
});

/// Reactive holder of the learner's [UserProfile].
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier(this._repo) : super(UserProfile.empty) {
    _load();
  }

  final UserProfileRepository _repo;

  Future<void> _load() async {
    final result = await _repo.getProfile();
    result.fold(
      (_) {}, // keep empty defaults on failure
      (profile) => state = profile,
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

  /// Add XP and return the new total.
  Future<int> addXp(int amount) async {
    final result = await _repo.addXp(amount);
    final next = result.fold((_) => state.xpTotal, (v) => v);
    state = state.copyWith(xpTotal: next);
    return next;
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
  return UserProfileNotifier(ref.watch(userProfileRepositoryProvider));
});
