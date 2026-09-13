/// VaaniX VAN Speech Strip
///
/// A compact companion line for surfaces where the full-size VAN would crowd
/// the task: lesson introductions, exam preparation, results, error and
/// offline moments. VAN speaks from the left edge; the message sits in a
/// soft speech container that mirrors the full-size speech bubble language.
///
/// The avatar is rendered through [VanWidget] at strip size so the visual
/// stays replaceable when final VAN artwork lands.
///
/// The strip animates in on first render (subtle fade + slide-up). Set
/// [animate] to [false] for list items that rebuild frequently.
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

// M10 QA fix: the strip's [state] parameter takes [VanState], so every
// consumer needs the enum visible. Dart imports are not transitive —
// previously each caller had to import van_widget/van_state directly
// (or, as the Exam Mode 2.0 screens shipped in M2-M9 accidentally
// did, rely on it being visible when it was not — a latent compile
// error caught by the M10 wiring). Exporting it here mirrors
// van_widget.dart (which exports it for the same reason) and makes
// every VanSpeechStrip consumer compile as written.
export 'package:vaanix_app/features/van/domain/van_state.dart';

class VanSpeechStrip extends StatefulWidget {
  const VanSpeechStrip({
    super.key,
    required this.message,
    this.state = VanState.idle,
    this.isLoading = false,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.animate = true,
  });

  final String message;
  final VanState state;
  final bool isLoading;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  /// Whether to animate the strip's entrance. Set to [false] when embedded
  /// in a list that rebuilds frequently (e.g., live typing feedback).
  final bool animate;

  @override
  State<VanSpeechStrip> createState() => _VanSpeechStripState();
}

class _VanSpeechStripState extends State<VanSpeechStrip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.animate) {
      Future.microtask(() {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget stripContent = Padding(
      padding: widget.margin,
      child: Semantics(
        label: 'Van says: ${widget.message}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ExcludeSemantics: the strip already announces "Van says: …"
            // as ONE node; without this the inner VanWidget's own
            // "Van is …" label would be announced a second time.
            ExcludeSemantics(
              child: VanWidget(
                size: AppDimens.vanSizeStrip,
                state: widget.state,
                isLoading: widget.isLoading,
                onTap: widget.onTap,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryContainerDark
                      : AppColors.primaryContainerLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  widget.message,
                  style: AppTextStyles.vanDialogue(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion || !widget.animate) return stripContent;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: stripContent),
    );
  }
}
