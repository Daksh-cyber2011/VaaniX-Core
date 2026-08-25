# Learn Mode (V1)

Flow: **READ -> LEARN -> PRACTICE -> FEEDBACK -> MASTER -> COMPLETE**

1. **Read** - lesson content screen renders the markdown-like lesson
   (headings, tables, tips) with Devanagari-aware typography.
2. **Learn** - the content itself (vowels, consonants, barakhadi,
   greetings, family, numbers, intro, questions).
3. **Practice** - `ExerciseScreen` runs the exercise engine:
   - MCQ / fill-in-the-blank: option tiles, deterministic display order.
   - Ordering: tap items into the correct sequence.
   - Feedback card shows correct/wrong + explanation after every answer.
4. **Master** - scoring counts each exercise once (first correct answer);
   retry improves understanding without inflating the score.
5. **Complete** - finishing a session marks the lesson complete via the
   idempotent progress path (XP awarded exactly once), fires VAN events
   and unlocks achievements through the same checker as the lesson screen.

Engines are content-driven: 4 exercises x 8 lessons are seeded; new
content drops into `sanskrit_exercises.dart` without UI changes.