/// Exercise Screen - Empty-State Widget Test
///
/// A lesson with no authored exercises must render the polished empty
/// state (VAN guidance + back action) instead of crashing on an empty
/// exercise list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/auth/data/noop_auth_repository.dart';
import 'package:vaanix_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vaanix_app/features/learn/presentation/providers/exercise_providers.dart';
import 'package:vaanix_app/features/learn/presentation/screens/exercise_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

const Lesson kEmptyLesson = Lesson(
  id: 'ls_no_exercises',
  chapterId: 'ch_test',
  title: 'No Exercises Yet',
  order: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty exercise list renders the safe empty state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(NoopAuthRepository()),
        exerciseSessionProvider(kEmptyLesson.id)
            .overrideWith((ref) => ExerciseNotifier(const [])),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: const MaterialApp(
          home: Scaffold(body: ExerciseScreen(lesson: kEmptyLesson)),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('No practice exercises for this lesson yet.'),
      findsOneWidget,
    );
    expect(find.text('Exercises are being prepared.'), findsOneWidget);
    expect(find.text('Back to lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Drain the speech-bubble timer from the const VanWidget.
    await tester.pump(const Duration(seconds: 2));
  });
}
