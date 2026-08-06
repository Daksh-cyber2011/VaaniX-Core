/// User Profile Repository — Domain Contract
///
/// Abstract interface for reading and writing the learner's profile.
/// Implementations: [LocalUserProfileRepository] (offline-first),
/// Supabase-backed repository (when backend is configured).

import 'package:vaanix_app/core/utils/result.dart';
import 'package:vaanix_app/features/profile/domain/user_profile.dart';

abstract class UserProfileRepository {
  /// Load the full profile snapshot.
  Future<Result<UserProfile>> getProfile();

  /// Persist the entire profile.
  Future<Result<void>> saveProfile(UserProfile profile);

  // ─── Field-level updates (avoid full overwrites for common edits) ────────

  Future<Result<void>> updateCompanionName(String name);
  Future<Result<void>> updatePersonalityMode(PersonalityMode mode);
  Future<Result<void>> updateCbseClass(CbseClass? cbseClass);
  Future<Result<void>> updateDailyGoal(int minutes);

  /// Mark today as active. Updates the streak:
  ///   - continued streak if last active was yesterday,
  ///   - reset to 1 if the streak was broken,
  ///   - unchanged if already active today.
  /// Returns the new streak count.
  Future<Result<int>> recordDailyActivity();

  /// Push local state to the cloud (no-op when offline / anonymous).
  Future<Result<void>> sync();
}
