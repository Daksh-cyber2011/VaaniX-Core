/// VaaniX Bootstrap Failure Surface
///
/// Rendered by `main()` when [bootstrap] throws — today the only rethrowing
/// step is `SharedPreferences.getInstance()`, which the app cannot run
/// without (every provider reads it through `sharedPreferencesProvider`).
///
/// Before this existed, a bootstrap throw propagated out of the guarded zone:
/// `runApp` was never reached, `handleZoneError` logged to Sentry, and the
/// user was left on the platform launch screen — a permanently blank app with
/// no message and no way forward.
///
/// Deliberate constraints:
///   * No Riverpod, no [ProviderScope], no router. Those all depend on the
///     very [SharedPreferences] instance that failed, so touching them here
///     would create the dependency cycle this screen exists to escape.
///   * Plain [MaterialApp] with [AppTheme.light]; that getter is a pure
///     ThemeData construction with no provider or preference reads.
///   * Retry is delegated upward via [onRetry] rather than calling
///     `bootstrap()` here, so the caller stays the single owner of the
///     start-up sequence and a successful retry enters the normal app.
library;

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_theme.dart';

class BootstrapFailureApp extends StatefulWidget {
  const BootstrapFailureApp({required this.onRetry, super.key});

  /// Re-runs the startup sequence. Completes when the attempt finishes;
  /// on success the caller replaces this widget with the real app, so this
  /// screen simply stays in its retrying state until it is torn down.
  final Future<void> Function() onRetry;

  @override
  State<BootstrapFailureApp> createState() => _BootstrapFailureAppState();
}

class _BootstrapFailureAppState extends State<BootstrapFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    // Guard against a double tap queueing two concurrent bootstraps.
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      // Only reached when the retry failed again (on success this widget has
      // been replaced by the real app root and is no longer mounted).
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaaniX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'VaaniX could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your device storage could not be opened, so your '
                    'progress could not be loaded. This is usually '
                    'temporary — please try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_retrying)
                    const CircularProgressIndicator()
                  else
                    FilledButton.icon(
                      key: const Key('bootstrap-retry'),
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
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
