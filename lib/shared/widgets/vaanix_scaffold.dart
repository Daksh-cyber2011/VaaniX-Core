/// VaaniX Scaffold — App Shell Widget
///
/// A standardized screen wrapper that applies consistent padding,
/// background color, and optional AppBar styling across all screens.
library;

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    Widget content = SafeArea(
      child: Padding(
        padding: padding,
        child: body,
      ),
    );

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      appBar: showAppBar
          ? AppBar(
              title: title != null
                  ? Text(
                      title!,
                      style: AppTextStyles.titleLarge(),
                    )
                  : null,
              leading: leading,
              actions: actions,
            )
          : null,
      body: content,
    );
  }
}
