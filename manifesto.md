# Spine — The Manifesto

> *Spine is not a bookstore. Spine is a reading gym.*

---

## What We Are

Spine is a **habit engine for readers**. It takes the psychology of Duolingo — streaks, XP, daily goals, level-ups — and applies it to the oldest human habit: reading books.

We don't sell books. We don't stream audiobooks. We don't recommend what to buy. We track what you *actually read*, reward you for consistency, and make the act of reading feel like progress instead of guilt.

---

## The Problem

Reading is one of the few universally respected habits that has *no product* built around the habit itself.

- **Kindle** is a bookstore that happens to let you read.
- **Audible** is a subscription service that happens to play audio.
- **Goodreads** is a social network that happens to track shelves.
- **Libby** is a library card that happens to render EPUBs.

None of them answer the question: **"Did I read today?"**

None of them make you *feel something* when you maintain a 14-day reading streak. None of them break a 300-page novel into a daily 10-minute habit. None of them care whether you read the EPUB on your phone *or* the paperback on your nightstand.

Spine does.

---

## Core Beliefs

### 1. Reading is a habit, not a purchase
The atomic unit of Spine is not a book. It's a **reading session**. A 10-minute session on a Tuesday night matters more than buying 12 books on Prime Day. We measure sessions, not shelves.

### 2. The format doesn't matter
A chapter completed on paper counts the same as a chapter completed in an EPUB. A chapter listened to in an audiobook counts the same as one read silently. Spine tracks *progress through stories*, not *pixels rendered on a screen*.

This is why we support:
- **EPUB imports** — digital books parsed into daily reading units
- **Audiobook alignment** — LibriVox/uploaded audio synced to EPUB text with fuzzy word-level matching
- **Physical book tracking** — paper books added manually with chapter-by-chapter tap-to-complete

All three earn XP. All three build streaks. All three count.

### 3. Streaks > libraries
A 30-day reading streak is worth more than a 300-book collection. Spine's entire reward system is designed around *consistency*, not *accumulation*. Every XP bonus, every achievement, every level-up rewards *showing up* — reading a little bit every day.

### 4. Small units, big momentum
We don't show you 400 pages and say "good luck." We break books into **5–10 minute reading units** (~1500–3000 words) and present one at a time. Complete one unit → earn XP → maintain your streak → come back tomorrow. The psychology is the same as a Duolingo lesson: short enough to finish, rewarding enough to return.

### 5. Intelligence should serve the reader, not the store
Every AI feature in Spine is built to make *reading* better, not to make *shopping* better:
- **Define a word** in context — not to sell you a dictionary
- **Explain a paragraph** — not to write a review
- **Recap the story so far** — not to generate marketing copy
- **Character tracker** — not to power "customers also bought"
- **Audiobook alignment** — not to upsell, but to let you switch formats mid-chapter

All AI runs **100% on-device** via Apple Foundation Models. No API keys. No data sent to servers. No model call ever sees the user's reading data outside their own phone.

### 6. Social features serve accountability, not performance
Reading clubs in Spine are for **accountability**, not showing off. Chapter-gated discussions prevent spoilers. Streak sharing motivates friends. No follower counts. No reading-speed leaderboards. No performative book lists.

---

## Who Spine Is For

Spine is for people who **want to read more** but don't. People who buy books and don't finish them. People who read in bursts then stop for months. People who listen to audiobooks on their commute but lose their place in the physical book on their nightstand.

Spine is not for:
- People looking for a bookstore
- People who want to catalog their library for others to see
- People who read 50 books a year and just need a shelf

Spine is for the reader who finished one chapter on Tuesday and wants something — anything — to acknowledge that *that mattered*.

---

## The Reading Gym Metaphor

A gym doesn't sell weights. A gym doesn't make your muscles bigger in one session. A gym is a *place and a system* that makes showing up consistently produce visible results over time.

Spine is that system for reading:

| Gym | Spine |
|-----|-------|
| Workout | Reading session (one unit) |
| Rep | Paragraph |
| Set | Reading unit (~5–10 min) |
| Personal record | Fastest WPM |
| Streak | Consecutive days with a completed session |
| Trainer | AI recap, word definitions, character tracker |
| Weight rack | Library (EPUBs, audiobooks, physical books) |
| Membership | Free — the content is public domain or user-owned |

You don't go to the gym to *buy* equipment. You go to the gym to *use* equipment consistently. Spine is the same.

---

## What We Build

Every feature passes one test: **Does this make the user more likely to read tomorrow?**

- ✅ XP for completing a chapter tap on a physical book → **yes**, it maintains the streak
- ✅ Audiobook alignment with karaoke text → **yes**, it lets users switch between commute and couch seamlessly
- ✅ Spoiler-safe AI recaps → **yes**, it reduces friction for returning after a gap
- ✅ Chapter-gated discussions → **yes**, it creates social accountability without spoilers
- ❌ Star ratings on a public profile → **no**, that's performance, not habit
- ❌ Book purchase links → **no**, that's retail, not reading
- ❌ Social reading feeds → **no**, that's content, not consistency

---

## The Stack

| Layer | Tool | Why |
|-------|------|-----|
| Data | SwiftData (local only) | Privacy-first. No server. Your reading data never leaves your phone. |
| AI | Apple Foundation Models | On-device. No API keys. No network. Degrades gracefully. |
| Audio | Speech framework | On-device ASR for audiobook alignment. No transcription servers. |
| Social | CloudKit (manual sync) | Lightweight social via Apple's privacy-respecting cloud kit. |
| Design | Custom tokens (SpineTokens) | Warm, premium, book-club aesthetic. Not tech-minimalist. Not gamification-loud. |

---

*Spine: show up, read a little, come back tomorrow.*
