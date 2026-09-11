/// VaaniX Learn Mode — Language Selection Repository (Part 0 Foundation)
///
/// Persistence layer for the user's currently selected Learn Mode
/// language. Wraps [ILocalStorageService] so the selection survives app
/// restarts and so the picker / Learn screen can read it reactively
/// through [selectedLearnLanguageProvider].
///
/// Storage contract:
/// - Key: [AppConstants.keyLearnLanguage]
/// - Value: the [LearnLanguage] enum name (e.g. `'hindi'`, `'urdu'`)
/// - Absent / null = no language selected yet
/// - Unknown value = treated as null (corruption-safe; the Learn screen
///   falls back to the unselected state instead of crashing).
///
/// Part 0 scope: persistence + retrieval ONLY. No curriculum loading,
/// no per-language XP isolation, no AI context wiring — those land in
/// Parts A–K once curricula exist.
library;

import 'package:vaanix_app/core/constants/app_constants.dart';
import 'package:vaanix_app/core/storage/i_local_storage_service.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';

class LearnLanguageRepository {
  LearnLanguageRepository(this._storage);

  final ILocalStorageService _storage;

  /// Currently selected Learn Mode language, or `null` when unset.
  ///
  /// Reads the stored enum name and resolves it through the catalogue.
  /// A stored value that isn't a known catalogue member is treated as
  /// unset — this keeps a corrupt store from breaking the app.
  LearnLanguage? get selected {
    final raw = _storage.getString(AppConstants.keyLearnLanguage);
    if (raw == null || raw.isEmpty) return null;
    return learnLanguageSpecByName(raw)?.language;
  }

  /// Persists [language] as the current selection.
  Future<void> setSelected(LearnLanguage language) {
    return _storage.setString(
      AppConstants.keyLearnLanguage,
      language.name,
    );
  }

  /// Clears the selection (sign-out / reset / "use legacy Sanskrit path").
  Future<void> clearSelected() {
    return _storage.remove(AppConstants.keyLearnLanguage);
  }
}
