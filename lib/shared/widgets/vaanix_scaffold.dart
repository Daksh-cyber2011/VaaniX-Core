/// VaaniX Scaffold — App Shell Widget
///
/// A standardized screen wrapper that applies consistent padding,
/// background color, and optional AppBar styling across all screens.
///
/// Automatically configures [SystemUiOverlayStyle] for the status bar so
/// the time/battery icons always contrast correctly with the theme — no
/// per-screen setup needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class VaaniXScaffold extends StatelessWidget {
  const VaaniXScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.showAppBar = true,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.onRefresh,
    this.appBarBottom,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showAppBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final RefreshCallback? onRefresh;

  /// Optional widget shown at the bottom of the AppBar (e.g. a TabBar).
  final PreferredSizeWidget? appBarBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBg = backgroundColor ?? theme.scaffoldBackgroundColor;

    // Status bar icons contrast: light icons on dark, dark icons on light.
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.light,
          );

    Widget content = SafeArea(
      child: Padding(
        padding: padding,
        child: body,
      ),
    );

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: theme.colorScheme.primary,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: content,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: effectiveBg,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        appBar: showAppBar
            ? AppBar(
                // Flat app bar — elevation comes from content, not the bar
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: effectiveBg,
                surfaceTintColor: Colors.transparent,
                title: title != null
                    ? Text(
                        title!,
                        style: AppTextStyles.titleLarge(
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      )
                    : null,
                // Styled back button (matches brand, not raw Material grey)
                leading: leading ??
                    (Navigator.of(context).canPop()
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            iconSize: 20,
                            tooltip: 'Back',
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null),
                actions: actions,
                bottom: appBarBottom,
                systemOverlayStyle: overlayStyle,
              )
            : null,
        body: content,
      ),
    );
  }
}
