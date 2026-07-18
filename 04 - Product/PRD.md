 VaaniX — Product Requirements Document (PRD)
Document Version: 1.0
Status: Draft — Awaiting Founder Approval
Last Updated: 2026-07-18
Author: Derived from VaaniX-Core Repository (Constitution + VAN Design Bible + Market Intelligence)
Scope: VaaniX Mobile App — Version 1.0 (MVP)

Table of Contents
Executive Summary
Product Vision & Mission
Constitutional Non-Negotiables
Target Audience & User Personas
Market Positioning
VAN — The AI Companion (Core Product Element)
App Architecture Overview
Feature Specifications
AI Architecture
Technical Stack
Database Schema
Design System
Gamification System
Monetization Strategy (V1)
Content Strategy (Sanskrit V1)
Key Performance Indicators (KPIs)
Development Roadmap
Risk Register
Open Questions & Decisions Needed
1. Executive Summary
VaaniX is a Sanskrit-first AI-powered language learning mobile application for Indian students (initially CBSE Class 6–10) that differentiates itself through one core idea: the learning companion comes first.

At the center of the experience is Van — a gender-neutral AI duck companion who studies with the student, not for them. Van is not a mascot, not a chatbot, not an assistant. Van is a living digital friend who remembers the student's journey, celebrates their wins, supports them through struggles, and makes every lesson feel personal.

The V1 product focuses on:

Sanskrit learning (CBSE curriculum-aligned)
Van as a fully animated, emotionally intelligent companion
Learn Mode (structured lessons)
Exam Mode (quiz and test preparation)
Achievement-based outfit/reward system (zero pay-to-win)
Streak and habit-building mechanics
Tech stack: Flutter (mobile) + FastAPI (Python backend) + Supabase (database & auth)

2. Product Vision & Mission
Vision
"A future where nobody has to learn alone. Every learner has a trustworthy AI buddy that helps them understand, communicate, explore languages and grow throughout life in a safe, encouraging environment."

Mission
"Build an ethical, high-quality AI learning platform that combines education, communication and language learning while continuously improving through real learner feedback."

Purpose
VaaniX exists to make learning enjoyable, meaningful and lifelong — not just exam-focused. The goal is to help learners build:

Confidence
Communication skills
The art of learning itself
The Founder's Oath / Decision Test
Every feature, design, and business decision must pass this 3-question test:

Does this increase trust?
Does it genuinely help learners?
Would we proudly explain this decision to our users?
If the answer to any is "No" — rethink it.

3. Constitutional Non-Negotiables
These are permanent, unchangeable commitments.

#	Non-Negotiable
1	Never manipulate learners
2	Never intentionally reduce quality for profit
3	Never break user trust
4	Never stop listening to feedback
5	Never forget the mission is to help people grow
6	Never guilt-trip users for absence or mistakes
7	Never introduce pay-to-win mechanics in V1
8	Never use dark patterns in notifications
9	Success = trusted impact + confident learners
10	Failure = when trust is lost or learning quality is sacrificed
4. Target Audience & User Personas
Primary Target (V1)
Indian students, CBSE curriculum, Class 6–10, learning Sanskrit

Persona 1: Aarav — The Reluctant Sanskrit Student
Age: 14, Class 9 CBSE
Location: Tier-1/Tier-2 Indian city
Device: Android mid-range phone
Pain Point: Sanskrit feels boring and useless; learns only because it's in the syllabus
Goal: Pass Sanskrit exams without hating the subject
Motivation Style: Gamification, streaks, humor
Van interaction: Wants Van to be funny and casual; loves duck puns
Risk of churn: HIGH — will stop if the app feels like homework
Persona 2: Priya — The Diligent Learner
Age: 12, Class 7 CBSE
Location: Metro city
Device: iOS or Android, mid-to-high range
Pain Point: Studies hard but lacks confidence; anxious before exams
Goal: Understand Sanskrit deeply, not just memorize
Motivation Style: Encouragement, progress tracking, clear explanations
Van interaction: Wants Van to be warm and patient; cannot feel judged for mistakes
Risk of churn: LOW if Van handles mistakes with empathy
Persona 3: Rohan — The Heritage Learner
Age: 16, Class 11 (optional Sanskrit)
Pain Point: Took Sanskrit for cultural reasons, finds formal study dry
Goal: Understand Sanskrit scripture and culture
Motivation Style: Depth, meaning, context
Van interaction: Wants substance, not baby steps
Secondary Target (V2+)
Heritage Sanskrit learners worldwide
Adult learners interested in Sanskrit
Students of other Indian classical languages
5. Market Positioning
Competitive Landscape
App	Strength	Weakness	VaaniX Opportunity
Duolingo	Gamification, global brand	Not CBSE-aligned, manipulative mechanics	Authentic Indian context, ethical mechanics
Babbel	Pedagogy, adult focus	No Sanskrit, not Indian	Fill the Sanskrit gap entirely
Busuu	Community	No Sanskrit	—
Little Guru	Indian, Sanskrit	Weak UX, no AI companion	Out-design them completely
Memrise	Vocab memory	No full learning path	—
VaaniX Differentiators
Van — No competitor has an emotionally intelligent AI companion of this depth
Sanskrit-first — Underserved, culturally resonant, CBSE curriculum-aligned
Pedagogy-first — Fixes teaching before polishing UI
Zero manipulation — No guilt, no energy systems, no dark patterns
Achievement-only rewards — No pay-to-win; trust = retention
6. VAN — The AI Companion (Core Product Element)
Van is not a feature. Van is the product's core identity.

6.1 Identity
Attribute	Specification
Internal Code Name	duck (never changes)
Default Public Name	Van
User Can Rename	Yes, anytime, any name
Species	Duck (always recognizable, never uncanny)
Gender	Neutral (never confirmed, never denied)
Pronouns	Avoided in all dialogue
6.2 Visual Specification
Art Style: Modern flat 2D vector illustration
Inspiration: Duolingo's visual simplicity + unique personality

Body Proportions:

Head: ≈45% of total height
Body: ≈35%
Legs: ≈10%
Feet: ≈10%
Default Color Palette:

Body: Soft warm yellow (#F4C74A)
Beak & Feet: Warm orange (#F07A33)
Eyes: Soft black pupils + tiny white highlight
Default Outfit: Blue hoodie, white drawstrings, VaaniX chest logo, orange feet visible
Design Rules:

❌ No sharp edges
❌ No thick outlines
❌ No realistic feathers
❌ No uncanny anatomy
✅ Scales from 24×24px icon to full-screen perfectly
✅ Recognizable as black silhouette
Signature Features (never remove):

Feather tuft on head (bounces during movement)
Wide soft beak (stretches during speech)
Large rounded eyes (primary emotion carrier)
6.3 Emotional Expression System
8 Primary Emotion Families × 3 Intensity Levels:

Family	Trigger	Light → Medium → Strong
😊 Happy	Correct answer, login, streak	Soft Smile → Big Smile → Celebration
🤔 Thinking	Processing, waiting, explaining	Looking Up → Chin Pose → Deep Think
🎯 Focus	During quizzes	Serious → Determined → Locked In
❤️ Caring	User struggling	Gentle Smile → Supportive → Comfort
😲 Surprise	Achievements	Shock → Amazed → Star Eyes
😢 Sad	Mild only, never depressing	Small Frown → Worried → Oops Face
😂 Funny	Humor moments	Wink → Tongue Out → Playful Laugh
🏆 Achievement	Streaks, milestones	Victory Pose → Medal → Trophy Lift
Eye Library (12 types): Normal, Happy Crescent, Wide Open, Suspicious, Gentle Pleading, Confident, Sleepy, Looking Up/L/R, Reading, Dreaming, Sparkly, Star Eyes, Warm Caring (rare)

Beak Library: Closed, Small Smile, Big Smile, Open Laugh, Talking, Surprise-O, Shock, Pout, Thinking, Whistle

Wing Gesture Library: Wave, Point, Clap, Celebrate, Shrug, Hold Book, Hold Pencil, High Five, Typing, Writing, Stretch, Peek, Hide

6.4 Animation System
Core Principles (ALL animations must follow):

✅ Ease In / Ease Out
✅ Slight Bounce (spring physics)
✅ Follow Through
✅ Overlapping Motion
✅ Squash & Stretch (max 15%)
✅ Anticipation frames
✅ Secondary Motion (feather tuft, wings)
❌ Never instant state switch
❌ Never stiff/mechanical
Animation Speed Reference:

Type	Speed
Idle breathing	Very slow (3–4s cycle)
Talking	Natural (lip-sync)
Celebration	Fast + energetic
Thinking	Medium
Teaching	Calm
Error	Quick
Success	Energetic
Idle System: 10 idle states, weighted random selection with 30-second cooldowns:

Normal breathing (highest weight)
Blink
Look around
Feather tuft bounce
Tiny stretch
Head tilt
Smile at nothing
Look at user (camera direction)
Look at notebook (downward)
Small wing adjustment
Transition Rule: Always: State A → Intermediate → State B. Never skip states.

6.5 Personality & Behaviour
Formula: 40% cute duck + 25% golden retriever energy + 20% smart teacher + 10% funny best friend + 5% tiny gremlin

Behaviour Hierarchy (Van evaluates in this order):

Is the student okay?
What is their goal?
What will help the most?
Can I make this enjoyable?
Keep response short unless detail is requested.
Communication Rules:

Situation	❌ Never	✅ Always
Wrong answer	"Wrong." / "Incorrect."	"Almost! Let's look at that together."
Long absence	"Where have you been?!"	"It's nice to see you again."
Struggling	"Believe in yourself!"	"Today's hard. Let's do one question together."
Good answer	"You're so smart!"	"Nice work — you stuck with a tough question."
Communication Modes:

Mode	Tone	Example
🌞 Friendly	Warm, casual	"Ready to learn something new?"
📚 Teaching	Calm, patient, step-by-step	Structured explanations
🎉 Celebration	Energetic, fun	"You did it! 🎉"
❤️ Support	Soft, gentle	"Take your time."
🎯 Focus	Serious, direct	"Read the question carefully."
Humor Rules:

✅ Duck puns (occasional): "Quack... give me one second."
✅ Wholesome: "You unlocked Duck Wisdom."
❌ Never cringe, never at user's expense, never excessive
Emoji Rules:

Use: 😊 🎉 ✨ 🦆 📚 ⭐ (max 1–2 per message)
Avoid: 😂😂😂 / 🔥🔥🔥 / 😈💀
6.6 Van's World — The Nest
Van lives in "The Nest" — a cozy digital learning space on the Home Screen.

Elements: 📚 Books · 🗺 Maps · 🌱 Plants · 🦆 Duck decorations · ☕ Warm lighting · 📝 Sticky notes · 🌎 Globe

Progression: The Nest visually evolves and becomes richer as the user levels up. New decorations unlock at milestones.

7. App Architecture Overview

VaaniX App
├── Auth Layer (Supabase)
│   ├── Phone OTP
│   ├── Google Sign-In
│   └── Email/Password
│
├── Onboarding Flow (7 screens)
│
├── Home — The Nest
│   ├── Van animated companion
│   ├── Daily lesson CTA
│   ├── Streak + XP display
│   └── Bottom navigation
│
├── Learn Mode
│   ├── Lesson tree (chapter-based)
│   ├── 6 lesson types
│   ├── Van reactions per answer
│   └── Post-lesson celebration
│
├── Exam Mode
│   ├── Practice Quiz
│   ├── Chapter Test
│   ├── Mock Test (timed)
│   ├── Weak Area Drill
│   └── Daily Quiz
│
├── Progress
│   ├── Streak calendar (heatmap)
│   ├── XP graph
│   ├── Chapter map
│   └── Van's assessment text
│
├── Van Profile
│   ├── Outfit customization
│   ├── Earned accessories
│   └── Personality mode
│
└── Settings
    ├── Notifications
    ├── Daily goal
    ├── Language (EN/HI)
    └── Account
8. Feature Specifications
8.1 Onboarding Flow
Goal: First impression = "Aww, I trust this duck" within 30 seconds.

Screen	Content	Van Action
1. Splash	VaaniX logo + Van first appearance	Blink, look around, feather bounce
2. Welcome	Name Van / accept default	Van walks in, dialogue bubble appears
3. Personality Mode	Select Cheerleader / Calm / Fun	Van reacts to each selection
4. Subject Setup	Select class (6–10), board (CBSE)	—
5. Daily Goal	Select 5/10/15/20 min	Van reacts to choice
6. Account Creation	Phone OTP or Google	Minimal form
7. Nest Reveal	First view of The Nest	Van: "This is where we'll study together."
8.2 Home Screen — The Nest

┌────────────────────────────┐
│  [🔥 Streak] [⭐ XP] [👤] │  ← Top bar
│                            │
│      🎨 The Nest BG        │
│                            │
│         🦆 VAN             │  ← Animated, interactive
│    [Van dialogue bubble]   │
│                            │
│  ┌──────────────────────┐  │
│  │  📚 Continue Lesson  │  │  ← Primary CTA
│  └──────────────────────┘  │
│  [📝 Exam][📊 Progress][👕] │  ← Bottom nav
└────────────────────────────┘
Van Daily Greeting Logic:

Condition	Van Says
First open of day, streak active	"Morning! Streak's safe. Let's keep it going!"
Streak at risk (≤4hrs left)	"Quick — we've got until midnight. One lesson?"
Streak just broke	"It's okay. Every champion has off days. Start fresh?"
Long absence (>7 days)	"It's so nice to see you again." (zero guilt)
Yesterday was perfect score	"Yesterday was perfect. Let's see what today brings!"
Van Interactivity:

Tap Van → Random reaction from pool of 20+ responses
Long press → Rare special reactions (duck wisdom, silly face)
Idle animations play continuously (weighted random, cooldowns)
8.3 Learn Mode
Lesson Types:

Type	Description	Van Pose
Teach	Van explains concept step-by-step	Teaching with book
Translate	Sanskrit ↔ English/Hindi	Thinking while user thinks
Multiple Choice	Select correct answer	Neutral → reacts on answer
Fill in the Blank	Complete a sentence	Focus pose
Arrange Words	Drag-arrange tiles	Watching, head tilts
Flashcards	Vocabulary building	Casual study pose
Match Pairs	Connect word ↔ meaning	Observing
Per-Lesson Flow:

Van greeting for lesson ("Today we're learning Vibhakti! It's actually pretty cool.")
Concept intro (2–3 slides)
5–8 exercise questions
Van reacts to every single answer
Lesson complete → Van celebration + XP + streak update
Answer Feedback Matrix:

Scenario	Animation	Van Says
Correct (first try)	Happy → Big Smile	"Yes! That's exactly right! ⭐"
Correct (after attempt)	Proud Smile	"See? You got it!"
Wrong (first time)	Oops + Caring	"Not quite! Let me show you."
Wrong (twice)	Comfort pose	"Today's tricky. Let's go slow."
Perfect lesson	Celebration + Confetti	"Perfect score! That deserves a happy dance! 🎉"
IMPORTANT

NO Hearts/Lives System. VaaniX does not penalize learning attempts. Infinite retries always.

8.4 Exam Mode
Sub-Mode	Description	Timer	Van Presence
Practice Quiz	10 Qs, instant feedback	None	Active (coaching)
Chapter Test	Full chapter questions	Optional	Minimal (focus mode)
Mock Test	Full-length paper	Yes (3hr)	Minimal during, full after
Weak Area Drill	AI-selected weak topics	None	Active
Daily Quiz	5 Qs daily challenge	None	Active
Van Post-Exam Reaction:

Score	Van Emotion	Van Says
90–100%	🏆 Star Eyes + Trophy	"That was incredible! You absolutely crushed it!"
75–89%	😊 Proud Smile	"Really solid work! You're getting stronger every day."
50–74%	🤔 Thoughtful	"Good effort! Let's look at what we can improve."
<50%	❤️ Caring	"That was tough. Let's figure out which parts tripped you up."
8.5 Van's Companion Memory System
Van remembers across sessions:

Name user gave Van
User's nickname (if set)
Streak count + history
Total XP + level
Favorite/avoided lesson types (by performance)
Weak chapters (auto-detected)
Preferred personality mode
All unlocked achievements
Current outfit + accessories
Days since last session
Personality Modes:

Mode	Van Behavior
🎉 Cheerleader	High energy, frequent celebrations, exclamation marks
📚 Calm Guide	Patient, methodical, detailed explanations
😄 Fun Friend	Casual, jokes, duck puns more frequent
8.6 Progress & Streak System
Streak Rules:

1 lesson = streak maintained
Deadline: 11:59 PM local time
No streak freeze in V1 (honest, simple)
Streak break: Van says "It's okay" — never guilt-trips
XP Table:

Action	XP
Complete lesson	10 XP
Perfect lesson (all correct first try)	20 XP
Daily quiz	5 XP
Complete chapter	50 XP
Complete mock exam	30 XP
7-day streak bonus	25 XP
30-day streak bonus	100 XP
Level System: Levels 1–20 in V1. Each level unlocks a Nest decoration.

Progress Screen:

Streak calendar (GitHub-style heatmap)
Chapter completion map (tree visualization)
XP graph (weekly/monthly)
Weak areas list (AI-generated)
"Van's Assessment" — short personal summary from Van
8.7 Achievement & Outfit System
Unlock Table:

Achievement	Unlock
Day 1	Default Blue Hoodie (permanent)
7-Day Streak	Green Hoodie
30-Day Streak	Golden Hoodie
100 Lessons	Scholar Robe
Perfect Score	Trophy Badge accessory
Complete any exam	Graduation Cap
Birthday (from DOB)	Birthday Hat
Level 5	Explorer Jacket
Level 10	Scientist Coat
Level 15	Wizard Robe
Level 20	Space Explorer Suit
Diwali (date-triggered)	Festive Diwali Outfit
Christmas	Santa Hat
Accessory Categories:

Head: Cap, Beanie, Graduation Cap, Explorer Hat, Birthday Hat, Santa Hat, Headphones, Flower Crown
Face: Round Glasses, Square Glasses, Sunglasses, Monocle
Back: Backpack, Jetpack, Book Bag, Cape
Wings (hands): Book, Notebook, Magic Wand, Coffee Mug, Pencil, Map
Neck: Scarf, Bow Tie, Tie, Medal
Outfit Selection UI:

Mix-and-match accessories on Van
Live preview with idle animation
Locked items show: "Complete 100 lessons to unlock!"
8.8 Van's Diary
Milestone-unlocked diary entries written in Van's voice.

Unlock Triggers:

Complete Chapter 1
7-day streak
30-day streak
First perfect quiz
First exam completed
100 lessons completed
Sample Entry (Chapter 1):

"Today we finished Chapter 1 together. It looked difficult at first — all those new letters, all those sounds. But we kept going. I'm proud of how far we've come. One chapter down. Many more adventures ahead." — Van

Diary UI: Journal-style with paper texture, Van avatar on corner of each page, locked entries shown as silhouettes.

8.9 Settings & Profile
Profile: Van's current outfit (tap to edit) · User name (editable) · Van's nickname · Streak · XP + Level · Chapter completion % · Join date

Settings: Notifications (on/off, time) · Daily goal · Personality mode · App language (EN/HI) · Account (logout, delete)

Delete Account: Van says: "I'll miss you. But I'll be here if you come back."

8.10 Notifications System
Rules:

Max 1 push notification per day
Never between 10 PM – 7 AM
Zero guilt-based language
Never reference punishment or failure
Notification Types:

Trigger	Message
Daily reminder (user's chosen time)	"Van's waiting in the Nest. Ready for today?"
Streak at risk (≤4hrs, no lesson done)	"Quick one? Your streak's still safe until midnight."
Milestone achieved	"🏆 30-day streak! Golden Hoodie unlocked!"
New diary entry	"Van wrote something in the diary. Want to read it?"
Seasonal/festival	"Happy Diwali! Van's wearing something special today 🪔"
9. AI Architecture
9.1 Components
Van's Dialogue AI

LLM: Google Gemini / GPT-4o (TBD)
System prompt: encodes full VAN personality Bible (character, communication rules, tone, mistake handling, emoji rules)
Context injected per message: user name, Van name, lesson context, score, streak, personality mode
Response limits: 2 sentences (casual), 5 sentences (teaching)
Lesson Content AI

AI generates question variations and fill-in-blank alternatives
ALL AI-generated content requires human Sanskrit teacher review before going live
No AI improvises language facts
Weak Area Detection Engine

Tracks per-question accuracy over time
Flags topics with <70% accuracy as weak
Feeds into: Weak Area Drill, Van's assessment, lesson prioritization
Personalization Engine (V2)

Adjusts difficulty based on performance patterns
Learns preferred exercise types
Times recommendations to user's active hours
9.2 AI Guardrails
Rule	Implementation
Van never gives wrong Sanskrit	Human-verified content only
Van admits uncertainty	Forced by system prompt
No manipulation	Banned phrases list in prompt
Response length control	Hard token limits
Safe for children	Age-appropriate content filter layer
10. Technical Stack
Frontend
Technology	Purpose
Flutter 3.x	Cross-platform mobile (Android + iOS)
Dart	Primary language
Rive	Van's interactive animations (state machines)
Lottie	Simpler Van animations (JSON-based)
Riverpod	State management
go_router	Navigation
flutter_local_notifications	Push notifications
supabase_flutter	Supabase client SDK
Backend
Technology	Purpose
FastAPI (Python 3.11+)	REST API
Pydantic	Request/response validation
Uvicorn	ASGI server
Google Gemini API / OpenAI	Van's dialogue AI
LangChain	LLM orchestration (optional)
Database & Infrastructure
Technology	Purpose
Supabase (PostgreSQL)	Primary database
Supabase Auth	Authentication (OTP, Google, Email)
Supabase Storage	Audio, outfit image assets
Supabase Edge Functions	Serverless logic
Railway / Render	FastAPI backend hosting
Firebase Crashlytics	Crash reporting
Firebase Analytics	Usage analytics
DevOps
Technology	Purpose
GitHub Actions	CI/CD pipeline
Docker	Backend containerization
Fastlane	Automated app store deployment
11. Database Schema (High Level)
sql

-- Core user identity
users (
  id              UUID PRIMARY KEY,
  created_at      TIMESTAMP,
  phone           TEXT,
  email           TEXT,
  display_name    TEXT,
  van_nickname    TEXT DEFAULT 'Van',
  user_nickname   TEXT,
  dob             DATE,
  class_level     INT,           -- 6-10
  board           TEXT DEFAULT 'CBSE',
  personality_mode TEXT,         -- cheerleader | calm | fun
  daily_goal_min  INT DEFAULT 10,
  ui_language     TEXT DEFAULT 'en'
)
-- Progress tracking
user_progress (
  user_id         UUID REFERENCES users(id),
  total_xp        INT DEFAULT 0,
  current_level   INT DEFAULT 1,
  current_streak  INT DEFAULT 0,
  longest_streak  INT DEFAULT 0,
  last_lesson_date DATE,
  total_lessons   INT DEFAULT 0,
  total_perfect   INT DEFAULT 0
)
-- Lesson completion log
lesson_completions (
  id              UUID PRIMARY KEY,
  user_id         UUID,
  lesson_id       TEXT,
  chapter_id      TEXT,
  completed_at    TIMESTAMP,
  score           INT,           -- 0-100
  perfect         BOOLEAN,
  attempts        INT,
  xp_earned       INT
)
-- Unlocked achievements + outfits
user_achievements (
  id              UUID PRIMARY KEY,
  user_id         UUID,
  achievement_id  TEXT,
  unlocked_at     TIMESTAMP,
  outfit_unlocked TEXT
)
-- Active outfit configuration
user_outfits (
  user_id         UUID,
  active_outfit   TEXT,
  accessories     TEXT[]         -- array of equipped accessory IDs
)
-- Van's diary entries
diary_entries (
  user_id         UUID,
  entry_key       TEXT,          -- e.g., 'chapter_1_complete'
  unlocked_at     TIMESTAMP,
  read            BOOLEAN DEFAULT false
)
-- Lesson content
lessons (
  id              TEXT PRIMARY KEY,
  chapter_id      TEXT,
  unit_id         TEXT,
  title           TEXT,
  lesson_type     TEXT,
  content         JSONB,
  difficulty      INT,           -- 1-5
  estimated_min   INT,
  xp_reward       INT,
  reviewed_by     TEXT           -- Sanskrit teacher who approved
)
-- Question bank
questions (
  id              UUID PRIMARY KEY,
  lesson_id       TEXT,
  type            TEXT,          -- mcq | fill | arrange | translate | match
  prompt          TEXT,
  options         JSONB,
  correct_answer  TEXT,
  explanation     TEXT,
  difficulty      INT
)
12. Design System
Color Palette

-- Brand
--vaanix-blue:      #4A90D9    (primary, Van's hoodie)
--vaanix-gold:      #F4C430    (Van's body, achievement gold)
--vaanix-orange:    #F07A33    (Van's beak, accent)
-- Backgrounds
--nest-warm:        #FDF6E3    (warm off-white, The Nest)
--card-bg:          #FFFFFF
--surface:          #F7F9FC
-- Text
--text-primary:     #1A1A2E
--text-secondary:   #6B7280
--text-muted:       #9CA3AF
-- State Colors
--success:          #22C55E    (correct answers)
--warning:          #F59E0B    (streak at risk)
--error-soft:       #FCA5A5    (wrong — never harsh red)
--streak-fire:      #FF6B35
Typography

Font: "Nunito" (Google Fonts) — rounded, friendly, premium
Fallback: "Inter"
--text-hero:        32px bold      (Van's big moments)
--text-h1:          24px bold      (screen titles)
--text-h2:          20px semibold  (section headers)
--text-body:        16px regular   (main content)
--text-label:       14px medium    (labels, tags)
--text-caption:     12px regular   (timestamps, hints)
--text-van:         15px medium    (Van's dialogue, slightly distinct)
Component Design Rules
All corner radii: minimum 12px (rounded = friendly)
No sharp-edged buttons ever
Card shadows: soft, offset, never harsh
All interactive elements: scale 0.97 on tap
Transitions: 200–300ms ease-in-out
Van Dialogue Bubble
Soft rounded rectangle
Subtle drop shadow
Duck-tail pointer toward Van
White fill, thin blue border (#4A90D9)
Nunito 15px medium
Max 2 lines visible, expands for more
13. Gamification System
IMPORTANT

Gamification must reinforce learning outcomes, not just engagement. These are different things.

What VaaniX Gamifies ✅
Consistency (daily streaks)
Completion (lesson tree progress)
Mastery (perfect score tracking)
Growth milestones (XP levels, achievements)
Improvement (weak → strong area tracking)
What VaaniX Does NOT Gamify ❌
Speed (no timer pressure on Learn mode)
Social comparison (no public leaderboards in V1)
Anxiety (no hearts/lives system — ever)
Purchasing (no coins, no boosts)
Guilt (no streak freeze needed; no punishment for breaks)
Core Reward Loop

User completes lesson
      ↓
XP earned + Van celebration animation
      ↓
Streak + visual progress updated
      ↓
Achievement check triggered
      ↓
If unlock: Outfit / Accessory / Diary reveal
      ↓
Van: "Want to keep going?" CTA
14. Monetization Strategy (V1)
V1 = 100% free. No paid features. No premium tier. No ads.

Rationale:

Trust must be earned before monetization
Ads misalign incentives (engagement ≠ learning)
Pay-to-win destroys community trust permanently
First cohort defines brand reputation
V2+ Revenue Plan (not V1):

Optional premium subscription:
Offline mode
Advanced analytics
Additional languages/subjects
Special cosmetic outfits (cosmetic only, never performance-affecting)
Never: energy systems, ad revenue, paywalled core content
CAUTION

Any future paid feature must pass the Founder's Oath test. If it reduces trust or punishes learners — it does not ship.

15. Content Strategy (Sanskrit V1)
Curriculum Alignment
Board: CBSE
Classes: 6–10 (recommend starting with Class 9 for V1)
Textbook: Ruchira series (NCERT)
Review: Every piece of content reviewed by qualified Sanskrit teacher before going live
Unit Structure (Class 9 Example)

Unit 1: Devanagari Foundation
  - Lesson 1.1: Vowels (Svaras)
  - Lesson 1.2: Consonants (Vyanjanas)
  - Lesson 1.3: Conjunct consonants (Sanyuktaksharas)
  - 🧪 Chapter Quiz
Unit 2: Basic Grammar
  - Lesson 2.1: Nouns & Cases (Vibhakti 1–8)
  - Lesson 2.2: Pronouns (Sarvanam)
  - Lesson 2.3: Basic verb conjugation (Lakaras)
  - 🧪 Chapter Quiz
Unit 3: Vocabulary
  - Lesson 3.1–3.5: Ruchira Chapter 1–5 wordlist
  - Flashcard reviews
Unit 4: Sentences & Translation
  - Lesson 4.1: Simple sentences (Anvayi)
  - Lesson 4.2: Translation practice (Sanskrit ↔ Hindi/English)
  - 🧪 Chapter Quiz
Unit 5: Exam Preparation
  - Chapter-wise tests
  - Full mock paper (3hr)
  - Van's exam tips
Content Quality Standard
Accuracy > speed (never rush content to ship)
Every lesson reviewed by Sanskrit teacher (non-negotiable gate)
Explanations available in both English and Hindi
Examples grounded in CBSE Ruchira sentences
AI-generated variations must also be teacher-reviewed
16. Key Performance Indicators (KPIs)
North Star Metric
"% of users who demonstrably improve their Sanskrit performance between Day 1 and Day 30"

This measures learning, not just engagement. These must never be conflated.

Learning KPIs
KPI	Month 3 Target	Method
Lesson completion rate	>70% of started lessons	Backend event
Perfect score rate	>25% of completed lessons	Backend
Chapter completion	>40% complete ≥1 full chapter	Backend
Self-reported improvement	>60% in in-app survey	Survey at Day 30
Engagement KPIs
KPI	Month 3 Target	Notes
Day-1 retention	>60%	Industry avg: 25–40%
Day-7 retention	>30%	Industry avg: 10–20%
Day-30 retention	>15%	Industry avg: 5–10%
Avg session length	8–12 min	Matches daily goal
Users with 7+ day streak	>20% of DAU	
Users with 30+ day streak	>5% of DAU	
Trust KPIs
KPI	Target	Notes
App Store rating	≥4.5 ⭐	Core trust signal
Support ticket rate	<5% of MAU	
Uninstall-after-notification	<3%	Dark pattern check
Net Promoter Score	>50	
17. Development Roadmap
Phase 0 — Foundation (Weeks 1–4)
 Set up Flutter project with folder structure
 Set up Supabase (auth + database + storage)
 Set up FastAPI backend with basic endpoints
 Implement authentication (Phone OTP + Google)
 Define Van animation spec → commission Rive artist
 Hire/onboard Sanskrit teacher for content review
 Commission Van character illustration set (idle + 8 emotion families × 3 intensities)
 Design system documented and implemented in Flutter
Phase 1 — Van & Core Loop (Weeks 5–10)
 Build all 7 onboarding screens
 Build Home Screen / The Nest with Van animations
 Implement 3 lesson types (Teach, MCQ, Fill-in-blank)
 Build XP + streak system (backend + UI)
 Build Unit 1 complete lesson tree (content reviewed)
 Integrate Van dialogue AI (system prompt + Gemini/GPT-4o)
 Build progress screen (streak heatmap + chapter map)
 Van idle animation system (weighted random, cooldowns)
Phase 2 — Content & Exam Mode (Weeks 11–16)
 Complete all 6 lesson types
 Build Exam Mode (Practice Quiz + Chapter Test + Mock Test)
 Build Weak Area detection engine
 Content: Complete Units 2–3 (reviewed)
 Build achievement system + outfit unlock logic
 Build Van outfit/accessory customization UI
 Build Van's Diary (5 entries, full UI)
 Build notification system
Phase 3 — Polish & Launch Prep (Weeks 17–20)
 Settings screen (complete)
 Profile screen (complete)
 Content: Complete Units 4–5 (reviewed)
 All outfit/accessory assets finalized
 Performance optimization (cold start < 2 seconds)
 Android + iOS device testing matrix
 Beta test: 20 real CBSE students → collect feedback
 Bug fix sprint (2 weeks)
 App Store submissions (Google Play + Apple)
Phase 4 — Post-Launch (Month 4+)
 Weekly KPI review (learning + engagement + trust)
 Weekly content updates from teacher feedback
 V2 planning: additional classes, voice mode, language expansion
 Expand classes based on demand signals (7, 8, 10)
 Consider adjacent subjects based on user requests
18. Risk Register
Risk	Likelihood	Impact	Mitigation
Sanskrit content errors go live	Medium	High	Non-negotiable teacher review gate before publish
Van animations delayed / costly	High	High	Commission Rive artist with clear spec from Phase 0
App feels like homework → churn	Medium	High	Beta test with real students; Van personality is the differentiator
AI generates wrong Sanskrit	High	High	Van never improvises language facts; human content only
Low D7 retention	Medium	High	Focus beta on Persona 1 (Aarav, at-risk user)
Notifications cause opt-outs	Low	Medium	Follow notification rules strictly; test copy before launch
Scope creep delays launch	High	High	Lock V1 = Sanskrit + Class 9 only; strict feature freeze
Flutter animation tech debt	Medium	Medium	Use Rive state machines from Day 1
LLM costs too high at scale	Medium	Medium	Rate limit Van AI calls; cache common responses
Teacher unavailable for review	Medium	High	Sign contract with 2 reviewers; build review pipeline
19. Open Questions & Decisions Needed
IMPORTANT

These must be decided before Phase 0 engineering begins.

Which class level for V1 content launch?
Recommendation: Class 9 (highest exam pressure = clearest value proposition, largest CBSE Sanskrit cohort).

Van animation format: Rive vs. Lottie?
Rive: interactive state machines, better for Van's reactive expressions. Lottie: simpler, cheaper.
Recommendation: Rive. Decision required.

LLM provider for Van's dialogue?
Gemini (cost-effective, multilingual, on-device future) vs. GPT-4o (best quality, higher cost).
Budget consideration needed.

Placement quiz: mandatory or optional in onboarding?
Recommendation: Optional (don't gate onboarding). Decision needed.

Hindi UI: Phase 1 or Phase 2?
Most target users (CBSE Class 9 in Tier-2 cities) are Hindi-dominant.
Recommendation: Phase 1. Decision needed.

Sanskrit teacher engagement model?
Full-time / part-time / per-content-batch freelance? Budget and timeline impact needed.

Beta testing cohort sourcing?
Target 20 real CBSE students. School partnership? Personal network? Timeline?

App Store developer accounts?
Google Play ($25 one-time) + Apple Developer ($99/year). Accounts need to be created/purchased now.

Rive artist commission timing?
Van animations are the critical path for Phase 1. Must be commissioned in Phase 0.
Timeline + budget to confirm.

V1 scope: One class or multiple classes?
Strong recommendation: Class 9 only for V1. Expand only after learning metrics prove the model works.

This PRD is a living document. It updates as decisions are made, user feedback is gathered, and the product evolves. Every change must be checked against the VaaniX Constitution.

"Before every decision ask: Does this increase trust? Does it genuinely help learners? Would we proudly explain this decision to our users? If not, rethink it."
— VaaniX Constitution, Chapter 9 (Founder's Oath)

Document Status: Ready for Founder Review
Next Step: Resolve Open Questions in Section 19 → Begin Phase 0
