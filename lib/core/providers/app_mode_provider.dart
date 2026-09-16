/// VaaniX Dual-Engine Mode Provider
///
/// Manages the active engine mode:
/// 1. [AppMode.exam] — "Tactical Cockpit" (High stakes, timed mocks, CBSE board precision, dark HUD)
/// 2. [AppMode.learn] — "The Sanctuary" (Indic language immersion, phonetics, conversational AI tutor)
///
/// Toggling mode preserves all user progress, syllabus mappings, and test states.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaanix_app/core/providers/app_providers.dart';

enum AppMode {
  exam,
  learn;

  bool get isExam => this == AppMode.exam;
  bool get isLearn => this == AppMode.learn;

  String get label => switch (this) {
        AppMode.exam => 'EXAM',
        AppMode.learn => 'LEARN',
      };

  String get title => switch (this) {
        AppMode.exam => 'Tactical Cockpit',
        AppMode.learn => 'The Sanctuary',
      };
}

class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() {
    final storage = ref.watch(localStorageServiceProvider);
    final raw = storage.activeAppMode;
    return raw == 'exam' ? AppMode.exam : AppMode.learn;
  }

  Future<void> setMode(AppMode mode) async {
    if (state == mode) return;
    state = mode;
    final storage = ref.read(localStorageServiceProvider);
    await storage.setActiveAppMode(mode == AppMode.exam ? 'exam' : 'learn');
  }

  Future<void> toggleMode() async {
    final next = state == AppMode.exam ? AppMode.learn : AppMode.exam;
    await setMode(next);
  }
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);
