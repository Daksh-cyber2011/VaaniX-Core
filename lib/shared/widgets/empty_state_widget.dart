/// VaaniX Empty State Widget
///
/// Reusable placeholder UI displayed when a list or view has no data.
/// Fully theme-aware; the icon container carries a soft tint of the accent.
///
/// Supports an optional VAN companion for emotional resonance — use the
/// contextually correct [VanState] so VAN feels present, not pasted on:
///   - [VanState.idle]    → calm, neutral empty state (default)
///   - [VanState.happy]   → positive milestone (no weak areas 🎉)
///   - [VanState.caring]  → needs attention (no lessons yet, go explore!)
///   - [VanState.focus]   → challenge-ready (try your first practice!)
library;
import 'package:flutter/material.dart';
import 'package:vaanix_app/core/theme/app_dimens.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/van_widget.dart';

class EmptyStateWidget extends StatefulWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onActionPressed,
    this.iconColor,
    this.showVan = false,
    this.vanState = VanState.idle,
    this.vanMessage,
    this.animate = true,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Color? iconColor;

  /// Set to [true] to show a small VAN companion above the title. VAN makes
  /// empty states feel warm rather than blank.
  final bool showVan;

  /// The expression VAN should display. Defaults to [VanState.idle].
  final VanState vanState;

  /// Optional message in VAN's speech bubble.
  final String? vanMessage;

  /// Whether to animate the entry. Disable for lists that rebuild frequently.
  final bool animate;

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
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
      begin: const Offset(0, 0.08),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final accent = widget.iconColor ?? theme.colorScheme.primary;
    final subtext =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72);

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // VAN companion (optional, contextual)
            if (widget.showVan) ...[
              VanWidget(
                state: widget.vanState,
                size: AppDimens.vanSizeBubble + 24,
                showSpeechBubble: widget.vanMessage != null,
                dialogueText: widget.vanMessage,
              ),
              const SizedBox(height: AppDimens.space4),
            ] else ...[
              // Icon-in-circle when no VAN
              Container(
                padding: const EdgeInsets.all(AppDimens.space5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 44, color: accent),
              ),
              const SizedBox(height: AppDimens.space5),
            ],
            Text(
              widget.title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space2),
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(color: subtext),
              textAlign: TextAlign.center,
            ),
            if (widget.actionLabel != null &&
                widget.onActionPressed != null) ...[
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(
                label: widget.actionLabel!,
                onPressed: widget.onActionPressed,
                minimumSize: const Size(200, 48),
              ),
            ],
          ],
        ),
      ),
    );

    if (reduceMotion || !widget.animate) return content;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: content),
    );
  }
}
