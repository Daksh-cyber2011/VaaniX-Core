/// VaaniX Learn Mode — Language Selection Screen (Part 0 Foundation)
///
/// Lists the 10 VaaniX Learn Mode languages from the locked catalogue
/// and lets the learner pick the one they want to study. Selection is
/// persisted via [SelectedLearnLanguageNotifier] and the user is routed
/// back to `/learn` immediately after.
///
/// Design notes:
/// - Each tile shows the language's endonym (in its own script) as the
///   primary label, with the English name + script name as secondary.
///   This is so a learner who already reads the script can self-identify
///   visually before any English scaffolding.
/// - Urdu's tile advertises its RTL direction (the only one in the
///   catalogue); the tile itself stays LTR so the picker's geometry is
///   consistent. RTL rendering kicks in inside the curriculum content.
/// - The currently selected language (if any) shows a check mark.
/// - Tapping a tile that is already selected is a no-op (just pops back).
/// - Accessibility: each tile is a ButtonSemantics with a verbose label
///   that includes native name, English name, script, and selected state.
///
/// Part 0 scope: this screen is reachable from the Learn screen's AppBar
/// and works end-to-end, but selecting a language whose curriculum has
/// not shipped yet (all 10 in Part 0) will show a "curriculum coming
/// in Part X" state back on the Learn screen. Parts A–J replace that
/// state with the real curriculum.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/learn/domain/learn_language.dart';
import 'package:vaanix_app/features/learn/presentation/providers/learn_language_providers.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class LearnLanguageSelectionScreen extends ConsumerWidget {
  const LearnLanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(learnLanguageCatalogueProvider);
    final selected = ref.watch(selectedLearnLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return VaaniXScaffold(
      title: 'Choose a language',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intro banner: explains what this screen does and that more
            // languages are not on the roadmap (catalogue is locked).
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const VanWidget(
                    state: VanState.happy,
                    size: 84,
                    showSpeechBubble: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Which language would you like to learn?',
                          style: AppTextStyles.titleMedium(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick one to start your journey. You can switch '
                          'anytime from the Learn screen.',
                          style: AppTextStyles.bodyMedium(color: subtext),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final spec in catalogue)
              _LanguageTile(
                spec: spec,
                isSelected: selected == spec.language,
                onTap: () => _onTap(context, ref, spec.language),
              ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${catalogue.length} languages · VaaniX Learn Mode',
                style: AppTextStyles.labelSmall(color: subtext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    LearnLanguage language,
  ) async {
    await ref.read(selectedLearnLanguageProvider.notifier).select(language);
    if (!context.mounted) return;
    context.go(RouteNames.learn);
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.spec,
    required this.isSelected,
    required this.onTap,
  });

  final LearnLanguageSpec spec;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    // Verbose semantic label so a screen reader announces everything
    // a sighted user sees: endonym, English name, script, direction,
    // and selection state. Tile is a button (not a row) so it gets the
    // tap trait by default.
    final semanticsLabel = [
      spec.nativeName,
      spec.englishName,
      'written in ${spec.scriptName}',
      if (spec.isRTL) 'reads right to left',
      if (isSelected) 'currently selected',
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  // Native name in big type. Flutter's font fallback
                  // chain handles every script in the catalogue
                  // (Devanagari, Bengali, Telugu, Tamil, Gujarati,
                  // Arabic/Nastaliq, Kannada, Malayalam, Odia) without
                  // bespoke font registration.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Direction-aware rendering for the endonym so
                        // Urdu's Nastaliq string is shaped correctly.
                        Directionality(
                          textDirection: spec.isRTL
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            spec.nativeName,
                            style: AppTextStyles.headlineSmall(),
                          ),
                        ),
                        Text(
                          spec.englishName,
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${spec.englishName} · ${spec.scriptName}'
                          '${spec.isRTL ? ' · RTL' : ''}',
                          style: AppTextStyles.bodySmall(color: subtext),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primary : subtext,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
