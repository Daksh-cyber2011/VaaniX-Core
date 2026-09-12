/// Exam Mode 2.0 — Shared Repository Providers (leaf)
///
/// M10 wiring fix: the PYQ-performance and mock-result repository
/// providers were defined inside [pyq_mock_providers.dart], which also
/// imports the weak-area providers — so the weak-area overview (which
/// reads both repositories, M9) could not import them without a
/// provider-file cycle. They are leaf dependencies (data classes +
/// storage only), so they live here where every consumer can import
/// them cleanly:
///
///   weak-area overview  →  PYQ performance + mock results (§21 feeds)
///   exam hub snapshot   →  PYQ totals + latest mock band
///   PYQ/mock controllers → their own persistence
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vaanix_app/core/providers/app_providers.dart'
    show localStorageServiceProvider;
import 'package:vaanix_app/features/exam/data/pyq_mock/pyq_performance_repository.dart';

final pyqPerformanceRepositoryProvider =
    Provider<PyqPerformanceRepository>((ref) {
  return PyqPerformanceRepository(ref.watch(localStorageServiceProvider));
});

final mockResultRepositoryProvider = Provider<MockResultRepository>((ref) {
  return MockResultRepository(ref.watch(localStorageServiceProvider));
});
