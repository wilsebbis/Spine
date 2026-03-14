# Spine 📚

**A reading gym for ambitious people.** Spine turns books into a daily habit — earning XP, maintaining streaks, and leveling up through 15 tiers. Read EPUBs, listen to audiobooks with word-level karaoke sync, or track your paperback chapter by chapter. All progress counts. All AI runs on-device.

> *Not a bookstore. Not a social network. A system that makes you more likely to read tomorrow.*
>
> See [manifesto.md](manifesto.md) for the philosophy. See [technical_doc.md](technical_doc.md) for the full architecture blueprint.

---

## Features

### 📖 Three Reading Formats — One Streak
| Format | How It Works |
|--------|-------------|
| **EPUB** | Parsed, segmented into ~10-minute units, rendered with selectable text and AI tools |
| **Audiobook** | LibriVox download or file upload, aligned to EPUB text for karaoke highlighting |
| **Physical Book** | Add title + chapter count, tap to complete each chapter on the honor system |

All three earn XP, build streaks, and track progress identically.

### 🔥 Habit Engine
- **Daily streaks** with flame badges and recovery messaging
- **XP system** — base XP + streak bonus + speed bonus + daily kickstart + book completion bonus
- **15 levels**: *Bookworm → Page Turner → … → Spine Master → Grand Librarian*
- **Reading speed tracking** with exponential moving average WPM
- **16 achievements** across Milestones, Streaks, Skills, and Lifestyle categories

### 🤖 On-Device AI (Apple Foundation Models)
- **Define Word** — contextual definitions from the text
- **Explain Paragraph** — plain-language explanations of complex passages
- **Story Recap** (V2 RAG) — hierarchical 5-tier memory with spoiler-safe retrieval
- **Ask the Book** — semantic Q&A over read content
- **Character Codex** — NLTagger entity extraction with mention counts and first appearances
- **Vocabulary Deck** — spaced repetition flashcard review of saved words

All AI is fully on-device via `LanguageModelSession`. No API keys. No network. Graceful degradation if unavailable.

### 🎧 Audiobook Alignment Pipeline
- **TextBlockClassifier** — classifies EPUB blocks (boilerplate, body text, headings, etc.)
- **AudioBoilerplateGater** — filters LibriVox disclaimers and narrator credits from ASR transcript
- **WordAlignmentEngine** — Smith-Waterman fuzzy alignment between EPUB text and audio
- **KaraokeTextView** — word-level highlighting with auto-scroll and tap-to-seek
- **AudioMiniPlayerView** — compact bottom bar with play/pause, skip, and progress

### 🎯 Recommendations
- Hybrid scoring: genre match (0.30) + vibe affinity (0.25) + synopsis similarity (0.20) + co-liked (0.15) + novelty (0.10) − avoided vibe penalty (0.40)
- `NLEmbedding` cosine similarity for synopsis matching — fully on-device
- Micro-reason feedback evolves taste profiles over time

### 👥 Social Layer (CloudKit)
- Chapter-gated discussions (no spoilers)
- Reading clubs with shared progress
- Highlight sharing
- Public profiles

### 📝 Engagement
- Highlight and note creation with color coding
- Post-unit reaction prompts (emoji chips + reflections)
- Quote saving
- Physical book notes and 5-star ratings

---

## Architecture

```
Spine/
├── App/                  # Entry point, tab bar
├── Design/               # SpineTokens design system, reusable components
├── Features/
│   ├── Gamification/     # XP bar, toasts, achievements, celebrations
│   ├── Highlights/       # Highlight list & management
│   ├── Library/          # Book grid, physical book tracker, add physical book
│   ├── Onboarding/       # Genre/vibe taste selection
│   ├── Paths/            # Curated reading paths
│   ├── Premium/          # Paywall
│   ├── Profile/          # Stats, achievements, settings, vocabulary
│   ├── Reactions/        # Post-reading feedback sheets
│   ├── Reader/           # EPUB reader, audiobook player, karaoke text,
│   │                     #   mini player, codex, recap, ask-the-book
│   ├── Social/           # Discussions, clubs, profiles, referrals
│   ├── Today/            # Daily dashboard
│   └── Vocabulary/       # Flashcard deck, review sessions
├── Models/               # SwiftData: Book, Chapter, ReadingUnit, XPProfile,
│                         #   AudiobookChapter, AudioSyncModels, VocabularyWord, etc.
├── Services/
│   ├── EPUBParser/       # EPUB extraction, HTML normalization, MiniZIP
│   ├── AudiobookAlignmentService  # EPUB ↔ audio alignment orchestrator
│   ├── AudioBoilerplateGater      # Non-book speech detection
│   ├── AudioPlaybackEngine        # AVFoundation audio player
│   ├── AudioSyncService           # Real-time sync coordinator
│   ├── BookRAGService             # V1 flat-chunk Q&A
│   ├── BookRAGServiceV2           # V2 hierarchical recap engine
│   ├── CharacterTracker           # NLTagger entity extraction
│   ├── CloudKitSocialService      # Social layer (manual CKRecord ops)
│   ├── EmbeddingService           # NLEmbedding wrapper
│   ├── FoundationModelService     # On-device LLM wrapper
│   ├── IngestionPipeline          # End-to-end EPUB import
│   ├── LibriVoxService            # Audiobook discovery
│   ├── ProgressTracker            # Reading progress & streaks
│   ├── RecommendationService      # Hybrid scoring engine
│   ├── SegmentationEngine         # Chapter → reading unit splitting
│   ├── TextBlockClassifier        # EPUB content classification
│   ├── WordAlignmentEngine        # Smith-Waterman fuzzy alignment
│   └── XPEngine                   # XP calculation & level progression
└── Stubs/                # Feature flags
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, Liquid Glass (iOS 26) |
| Data | SwiftData (local only) |
| AI | Apple Foundation Models (`LanguageModelSession`, `@Generable`) |
| NLP | NaturalLanguage (`NLEmbedding`, `NLTagger`) |
| Audio | AVFoundation, Speech framework |
| Social | CloudKit (manual sync, no auto-sync) |
| EPUB | Custom parser + MiniZIP |
| Concurrency | Swift 6, `@MainActor` |
| Dependencies | **Zero external** — pure Apple frameworks |
| Min Target | iOS 26 |

## Feature Phases

| Phase | Status | Features |
|-------|--------|----------|
| **1 — Core Habit** | ✅ Shipped | EPUB ingestion, segmentation, streaks, highlights, reactions, XP |
| **2 — AI + Open Import** | ✅ Shipped | Arbitrary EPUB import, define word, explain paragraph, unit recaps |
| **3 — Intelligence** | ✅ Shipped | V2 RAG recap, character codex, Ask the Book, X-Ray |
| **4 — Social** | ✅ Shipped | Chapter-gated discussions, reading clubs, public profiles, highlight sharing |
| **5 — Audio** | ✅ Shipped | LibriVox download, audiobook player, alignment pipeline, karaoke text |
| **6 — Physical Books** | ✅ Shipped | Manual book entry, chapter tracking, XP/streak integration, notes, ratings |

## Getting Started

### Requirements
- Xcode 26+
- iOS 26+
- Swift 6

### Build & Run
```bash
git clone https://github.com/wilsebbis/Spine.git
cd Spine/Spine
open Spine.xcodeproj
```

Select an iOS 26 simulator or device and hit **⌘R**.

The app ships with 6 bundled EPUBs (Alice in Wonderland, Frankenstein, Pride and Prejudice, Romeo and Juliet, The Great Gatsby, Wuthering Heights) that auto-ingest on first launch.

## Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | This file — project overview |
| [manifesto.md](manifesto.md) | Cultural purpose: why Spine exists, what we build and don't build |
| [technical_doc.md](technical_doc.md) | Full architecture blueprint — every model, service, algorithm, and enum |

## License

This project is provided as-is for portfolio and educational purposes.
