# VAN Design Bible

## 🎬 Chapter 4 — Animations

Version: 1.0
Status: Approved
Last Updated: 2026-07-17

The Animation Bible defines how Van moves, reacts, and communicates through motion.

Animation is one of the strongest parts of Van's personality. Every movement should reinforce the feeling that Van is a living learning companion—not just a static mascot.

This chapter establishes the principles, behaviors, and technical standards that every future animation must follow to ensure consistency across the VaaniX ecosystem.

1. Animation Philosophy

Van should never feel static.

Even when idle, Van should appear alive.

Every movement should feel:

Natural
Soft
Smooth
Friendly
Expressive
Premium
Playful

Never robotic.

Never stiff.

2. Animation Principles

Every animation follows these rules:

✅ Ease In

✅ Ease Out

✅ Slight Bounce

✅ Follow Through

✅ Overlapping Motion

✅ Squash & Stretch (subtle)

✅ Anticipation

✅ Secondary Motion

3. Animation Speed

Idle
Very Slow

Talking
Natural

Celebration
Fast

Thinking
Medium

Teaching
Calm

Reading
Slow

Error
Quick

Success
Energetic

4. Idle Animations

Van should perform idle animations using weighted random selection with cooldowns, so the same animation does not repeat too frequently.

Idle 1
Normal breathing

Idle 2
Blink

Idle 3
Look around

Idle 4
Feather tuft bounce

Idle 5
Tiny stretch

Idle 6
Head tilt

Idle 7
Smile

Idle 8
Look at user

Idle 9
Look at notebook

Idle 10
Small wing adjustment

These should play randomly so Van never feels repetitive.

5. Eye Animations

Blink

Double Blink

Slow Blink

Happy Blink

Sleepy Blink

Quick Look Left

Quick Look Right

Look Up

Look Down

Sparkle

6. Beak Animations

Talking

Laughing

Small Smile

Big Smile

Surprised Open

Thinking

Pout

Giggle

7. Wing Animations

Wave

Point

Clap

Celebrate

Shrug

Hold Book

Hold Pencil

High Five

Thumbs Up Equivalent

Typing

Writing

Stretch

Peek

Hide

8. Body Animations

Stand

Walk

Run

Hop

Jump

Spin

Sit

Lean

Bow

Dance

Stretch

Sleep

Wake Up

Celebrate

Teach

Listen

9. Transition Rules

Never instantly switch.

Always transition smoothly.

Example:

Thinking

↓

Smile

↓

Celebrate

Instead of

Thinking

↓

Celebrate

Some animations may be interrupted by higher-priority events.

Priority order:

Emergency system events
↓
User interactions
↓
Teaching animations
↓
Celebrations
↓
Idle animations

Example:

If Van is idling and the user taps "Next",
the idle animation should transition smoothly into the next interaction instead of finishing completely.

10. Learning Animations

Reading Book

Writing Notes

Highlighting

Opening Book

Closing Book

Turning Pages

Pointing to Text

Looking at Board

Checking Answer

Explaining

11. Quiz Animations

Question Appears

Thinking

Waiting

Correct Answer

Wrong Answer

Hint

Time Running Out

Excellent Score

Perfect Score

Retry

12. Celebration Animations

Tiny Celebration

Good Job

Level Up

Confetti

Happy Dance

Jump

Spin

Celebration Effects (confetti, sparkles, fireworks when appropriate)

Golden Glow

Champion Pose

13. Emotion Animations

Happy

Excited

Curious

Confused

Determined

Sleepy

Calm

Embarrassed

Proud

Supportive

14. System Animations

Loading

Downloading

Uploading

Sync Complete

Offline

Connection Lost

Update Complete

Achievement Saved

Daily Reward

Notification Pop

15. Seasonal Animations

Rain

Snow

Wind

Leaves Falling

Diwali

Holi

Christmas

Birthday

Exam Season

Summer Vacation

16. Companion Animations

Greeting

Goodbye

Morning

Night

Daily Reminder

Come Back Soon

Missed You

Long Time No See

Streak Reminder

Goal Complete

17. Rare Easter Egg Animations

Very rare.

Maybe once every few hundred interactions.

Examples:

Van moonwalks.

Van juggles books.

Van pretends to fly.

Van sleeps standing.

Van chases butterfly.

Van sneezes.

Van catches feather.

Van does tiny breakdance.

These make users smile unexpectedly.

18. Animation Priority

Highest Quality:

Greeting

Talking

Teaching

Celebration

Idle

Thinking

These are seen every day.

Lower Priority:

Holiday animations

Rare Easter eggs

Special outfits

Festival animations

19. Performance Rules

Animations should be modular and reusable.

For example:

One wave animation can be reused for:
• Greeting
• Goodbye
• Daily reminder
• Achievement celebration

This keeps the animation library smaller, more consistent, and easier to maintain.

Animations must:

Run smoothly at 60 FPS (where possible).

Be lightweight.

Not drain battery.

Pause when app is minimized.

Reduce motion if user enables accessibility settings.

20. Future Compatibility

Animation system should support:

Rive
Lottie
Flutter animation widgets
Live2D
Spine
Unity
3D animation
AR
VR
Robotics

So Van can evolve without redesigning everything.