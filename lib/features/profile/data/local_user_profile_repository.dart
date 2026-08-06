/// Local User Profile Repository — Data Layer
///
/// Offline-first implementation of [UserProfileRepository] backed by
/// [ILocalStorageService]. Every read and write is synchronous under the hood
/// (SharedPreferences), wrapped in [guardAsync] for a consistent failure API.
///
/// Cloud sync is delegated to [sync], which is a no-op until a remote
/// repository is wired in — this keeps the app fully functional offline.

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';
import 'package:vaanix_app/features/profile/domain/user_profile_repository.dart';

class LocalUserProfileRepository implements UserProfileRepository {
  LocalUserProfileRepository(this._storage);

  final ILocalStorageService _storage;

  @override
  Future<Result<UserProfile>> getProfile() {
    return guardAsync(() async {
      final personalityRaw = _storage.personalityMode;
      final personality = personalityRaw == null
          ? null
          : PersonalityMode.values.asNameMap()[personalityRaw];

      return UserProfile(
        companionName: _storage.companionName,
        personalityMode: personality,
        cbseClass: CbseClass.fromValue(_storage.selectedClass),
        dailyGoalMinutes: _storage.dailyGoalMinutes,
        currentStreak: _storage.currentStreak,
        lastActiveDate: _storage.lastActiveDate,
      );
    });
  }

  @override
  Future<Result<void>> saveProfile(UserProfile profile) {
    return guardAsync(() async {
      await Future.wait([
        _storage.setCompanionName(profile.resolvedCompanionName),
        if (profile.personalityMode != null)
          _storage.setPersonalityMode(profile.personalityMode!.name),
        if (profile.cbseClass != null)
          _storage.setSelectedClass(profile.cbseClass!.value),
        _storage.setDailyGoalMinutes(profile.dailyGoalMinutes),
        _storage.setCurrentStreak(profile.currentStreak),
        if (profile.lastActiveDate != null)
          _storage.setLastActiveDate(profile.lastActiveDate!),
      ]);
    });
  }

  @override
  Future<Result<void>> updateCompanionName(String name) =>
      guardAsync(() => _storage.setCompanionName(name));

  @override
  Future<Result<void>> updatePersonalityMode(PersonalityMode mode) =>
      guardAsync(() => _storage.setPersonalityMode(mode.name));

  @override
  Future<Result<void>> updateCbseClass(CbseClass? cbseClass) async {
    if (cbseClass == null) {
      return guardAsync(
        () => _storage.remove(AppConstants.keySelectedClass),
      );
    }
    return guardAsync(() => _storage.setSelectedClass(cbseClass.value));
  }

  @override
  Future<Result<void>> updateDailyGoal(int minutes) =>
      guardAsync(() => _storage.setDailyGoalMinutes(minutes));

  @override
  Future<Result<int>> recordDailyActivity() {
    return guardAsync(() async {
      final today = _utcMidnight(DateTime.now());
      final last = _storage.lastActiveDate;

      // Already active today — no change.
      if (last == today) return _storage.currentStreak;

      final yesterday = _utcMidnight(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      final newStreak = (last == yesterday)
          ? _storage.currentStreak + 1
          : 1; // streak broken or first run

      await Future.wait([
        _storage.setCurrentStreak(newStreak),
        _storage.setLastActiveDate(today),
      ]);

      return newStreak;
    });
  }

  @override
  Future<Result<void>> sync() async {
    // No-op until a remote store is wired in. Local is the source of truth
    // for anonymous users; the cloud sync layer will hook in here.
    return const Right(null);
  }

  /// Returns the UTC midnight ISO-8601 date string for [date].
  String _utcMidnight(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }
}
