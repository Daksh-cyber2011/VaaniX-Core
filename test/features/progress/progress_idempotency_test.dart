import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vaanix_app/core/storage/local_storage_service.dart';
import 'package:vaanix_app/features/progress/data/local_progress_repository.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';
import 'package:vaanix_app/features/progress/domain/progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    repo = LocalProgressRepository(LocalStorageService(prefs));
  });

  int readXp() =>
      repo.getXp().fold((_) => fail('expected xp success'), (v) => v);

  group('lesson XP idempotency', () {
    test('awards XP only once per lesson id', () async {
      const lesson = Lesson(id: 'l1', title: 'T', chapterId: 'c', xpReward: 15);
      await repo.completeLesson(lesson);
      await repo.completeLesson(lesson);
      expect(readXp(), 15); // not 30
    });

    test('records the lesson id exactly once', () async {
      const lesson = Lesson(id: 'l2', title: 'T', chapterId: 'c', xpReward: 10);
      await repo.completeLesson(lesson);
      await repo.completeLesson(lesson);
      final ids = repo
          .getCompletedLessonIds()
          .fold((_) => fail('expected ids success'), (v) => v);
      expect(ids.where((id) => id == 'l2'), hasLength(1));
    });
  });

  group('quiz XP idempotency + history', () {
    test('awards quiz XP once but appends history every time', () async {
      final first = await repo.completeQuiz(quizId: 'qz', score: 2, total: 3);
      final second = await repo.completeQuiz(quizId: 'qz', score: 3, total: 3);

      final xp1 =
          first.fold((_) => fail('expected success'), (r) => r.xpEarned);
      final xp2 =
          second.fold((_) => fail('expected success'), (r) => r.xpEarned);
      expect(xp1, 20); // 2 correct * 10
      expect(xp2, 0); // repeat -> no XP

      final history = repo
          .getQuizAttempts('qz')
          .fold((_) => fail('expected history'), (v) => v);
      expect(history, hasLength(2));
      expect(readXp(), 20); // only the first award persisted
    });
  });

  group('attempt history parsing', () {
    test('returns empty for a never-attempted quiz', () {
      final history = repo
          .getQuizAttempts('nope')
          .fold((_) => fail('expected empty history'), (v) => v);
      expect(history, isEmpty);
    });

    test('returns empty for corrupt JSON instead of throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quiz_attempts_bad', 'this is not json');
      final history = repo
          .getQuizAttempts('bad')
          .fold((_) => fail('expected empty history'), (v) => v);
      expect(history, isEmpty);
    });
  });
}
