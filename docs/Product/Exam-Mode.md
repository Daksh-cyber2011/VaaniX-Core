# Exam Mode (V1)

Flow: **Chapter -> Difficulty -> Question set -> Quiz -> Result -> Save**

- **Chooser**: pick a chapter (with question counts), then a difficulty
  tier (beginner / intermediate / advanced, with counts). Difficulty tags
  are derived from the chapter lesson bands, never invented.
- **Selection**: deterministic (sorted by id, no RNG) so attempts are
  reproducible and testable.
- **Quiz**: progress header, question card, options with correct/wrong
  coloring, explanation, VAN events (started / correct / wrong / perfect /
  completed).
- **Result**: score + accuracy, Save Progress (persists attempt history
  via `completeQuiz(quizId)`), Retry, Change topic.
- **XP**: awarded once per quiz id (idempotent); history appends every
  attempt.

Content: 20 grounded questions across the 3 chapters (10/8/3 by
difficulty). Engine complete; content can scale by adding questions to
`assets/curriculum/v1.json` (must stay in parity with the Dart fallback
map - enforced by `exam_content_grounding_test.dart`).