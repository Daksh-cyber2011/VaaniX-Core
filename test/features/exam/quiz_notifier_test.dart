import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/features/exam/presentation/providers/quiz_providers.dart';
import 'package:vaanix_app/features/progress/domain/progress_models.dart';

const _questions = [
  QuizQuestion(id: 'q1', prompt: '1?', options: ['a', 'b'], correctIndex: 0),
  QuizQuestion(id: 'q2', prompt: '2?', options: ['a', 'b'], correctIndex: 1),
];

void main() {
  group('QuizNotifier', () {
    test('starts at index 0 with 0 score and not finished', () {
      final n = QuizNotifier(_questions);
      expect(n.total, 2);
      expect(n.state.currentIndex, 0);
      expect(n.state.score, 0);
      expect(n.state.finished, isFalse);
    });

    test('submit without a selection is a no-op', () {
      final n = QuizNotifier(_questions);
      n.submit();
      expect(n.state.answered, isFalse);
      expect(n.state.score, 0);
    });

    test('correct answer increments score and marks answered', () {
      final n = QuizNotifier(_questions);
      n.select(0); // q1 correctIndex is 0
      n.submit();
      expect(n.state.score, 1);
      expect(n.state.answered, isTrue);
    });

    test('wrong answer does not increment score', () {
      final n = QuizNotifier(_questions);
      n.select(1); // q1 correctIndex is 0
      n.submit();
      expect(n.state.score, 0);
      expect(n.state.answered, isTrue);
    });

    test('cannot re-select after answering', () {
      final n = QuizNotifier(_questions);
      n.select(0);
      n.submit();
      n.select(1);
      expect(n.state.selectedOption, 0);
    });

    test('next advances and clears the selection', () {
      final n = QuizNotifier(_questions);
      n.select(0);
      n.submit();
      n.next();
      expect(n.state.currentIndex, 1);
      expect(n.state.answered, isFalse);
      expect(n.state.selectedOption, isNull);
    });

    test('next on the last question finishes the quiz', () {
      final n = QuizNotifier(_questions);
      n.select(0);
      n.submit();
      n.next(); // index 1
      n.select(1);
      n.submit();
      n.next(); // past the last -> finished
      expect(n.state.finished, isTrue);
    });

    test('restart resets all state', () {
      final n = QuizNotifier(_questions);
      n.select(0);
      n.submit();
      n.next();
      n.restart();
      expect(n.state.currentIndex, 0);
      expect(n.state.score, 0);
      expect(n.state.selectedOption, isNull);
      expect(n.state.answered, isFalse);
      expect(n.state.finished, isFalse);
    });
  });
}
