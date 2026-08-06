/// User Profile Repository — Domain Contract
///
/// Abstract interface for reading and writing the learner's profile.
/// Implementations: [LocalUserProfileRepository] (offline-first),
/// Supabase-backed repository (when backend is configured — deferred to
/// a Production milestone).
///
/// Note: The previous `sync()` method was removed in Segment 5. It was a
/// no-op stub that was never called, and its docstring falsely claimed
/// cloud sync was delegated to it. A real `SupabaseUserProfileRepository`
/// with sync will be added in a Production milestone when the backend is
/// ready. Until then, the profile is local-only (offline-first).

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
}
