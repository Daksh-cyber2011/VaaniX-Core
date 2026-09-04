/// Learn UI Navigation Tests (syllabus expansion)
///
/// Proves every NEW syllabus lesson is reachable through the real Learn
/// screen: curriculumProvider loads v1.json -> chapter tile expands ->
/// lesson tile navigates to LessonContentScreen.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/providers/app_providers.dart';
import 'package:vaanix_app/features/learn/data/unit2_lesson_content.dart';
import 'package:vaanix_app/features/learn/presentation/screens/learn_screen.dart';
import 'package:vaanix_app/features/learn/presentation/screens/lesson_content_screen.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

const List<String> kNewLessons = [
  'ls_alphabet_conjuncts',
  'ls_sentences_translation',
  'ls_grammar_nouns_cases',
  'ls_grammar_pronouns',
  'ls_grammar_verbs',
];

Map<String, dynamic> _loadJson() =>
    jsonDecode(File('assets/curriculum/v1.json').readAsStringSync())
        as Map<String, dynamic>;

class _Curriculum {
  _Curriculum()
      : lessons = [],
        titles = {},
        chapterTitles = {};

  final List<Lesson> lessons;
  final Map<String, String> titles; // lessonId -> rendered title
  final Map<String, String> chapterTitles; // chapterId -> rendered title

  Lesson byId(String id) => lessons.firstWhere((l) => l.id == id);
}

_Curriculum _build() {
  final json = _loadJson();
  final c = _Curriculum();
  for (final chapter in json['chapters'] as List) {
    final ch = chapter as Map<String, dynamic>;
    c.chapterTitles[ch['id'] as String] = ch['title'] as String;
    for (final lesson in ch['lessons'] as List) {
      final l = Lesson.fromJson(lesson as Map<String, dynamic>);
      c.lessons.add(l);
      c.titles[l.id] = l.title;
    }
  }
  return c;
}

Future<ProviderContainer> _makeContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every new lesson is reachable through the Learn screen',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final curriculum = _build();
    final container = await _makeContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnScreen(),
        ),
        GoRoute(
          path: '/learn/lesson/:lessonId',
          builder: (context, state) {
            // Mirror CurriculumLoader's content merge (JSON structure +
            // Dart content constants) for the route target.
            final base = curriculum.byId(state.pathParameters['lessonId']!);
            final content = unit2LessonContent[base.id];
            return LessonContentScreen(
              lesson: content == null ? base : base.copyWith(content: content),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Wait for the curriculum to load and the first frame to settle.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 300));

    for (final lessonId in kNewLessons) {
      final lesson = curriculum.byId(lessonId);
      final chapterTitle = curriculum.chapterTitles[lesson.chapterId]!;
      final lessonTitle = curriculum.titles[lessonId]!;
      final lessonTextFinder = find.text(lessonTitle);

      // Expand the chapter (retry taps until the lesson rows appear).
      // The Learn route is rebuilt after each go('/learn'), so always re-expand.
      for (var attempt = 0;
          attempt < 3 && lessonTextFinder.evaluate().isEmpty;
          attempt++) {
        await tester.tap(find.text(chapterTitle).first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }

      if (lessonTextFinder.evaluate().isEmpty) {
        final dumped = find.byType(Text).evaluate().map((e) {
          final w = e.widget as Text;
          return w.data ?? w.textSpan?.toPlainText() ?? '?';
        }).toList();
        fail('$lessonId not listed under $chapterTitle. '
            'Rendered texts: $dumped');
      }

      // Tap the lesson row (ListTile if present, else the title text).
      final rowFinder = find.ancestor(
          of: lessonTextFinder.first, matching: find.byType(ListTile));
      if (rowFinder.evaluate().isNotEmpty) {
        await tester.tap(rowFinder.first, warnIfMissed: false);
      } else {
        await tester.tap(lessonTextFinder.first, warnIfMissed: false);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Retry once if the route did not open (animation timing).
      if (find.byType(LessonContentScreen).evaluate().isEmpty) {
        final rowFinder2 = find.ancestor(
            of: lessonTextFinder.first, matching: find.byType(ListTile));
        if (rowFinder2.evaluate().isNotEmpty) {
          await tester.tap(rowFinder2.first, warnIfMissed: false);
        } else {
          await tester.tap(lessonTextFinder.first, warnIfMissed: false);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      // Lesson content screen opened for the right lesson.
      expect(find.byType(LessonContentScreen), findsOneWidget,
          reason: '$lessonId should open the lesson reader');
      expect(lessonTextFinder, findsWidgets,
          reason: '$lessonId title should render in the lesson reader');
      // Real lesson content must render (not a stub/placeholder).
      expect(find.textContaining('Content coming soon'), findsNothing,
          reason: '$lessonId must render real lesson content');

      // Back to Learn for the next lesson.
      router.go('/learn');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Drain VAN speech timers so the test ends with no pending timers.
    await tester.pump(const Duration(seconds: 8));
  });
}
