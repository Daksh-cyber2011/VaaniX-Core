/// VaaniX Navigator Keys
///
/// Global navigator keys are declared here as a standalone file so that
/// both [app_router.dart] and [navigation_service.dart] can import them
/// without creating a circular dependency.

import 'package:flutter/material.dart';

/// Root navigator key — used by [GoRouter] and [NavigationService] for
/// context-free dialog, snackbar and sheet access.
final rootNavigatorKey = GlobalKey<NavigatorState>();
