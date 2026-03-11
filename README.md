# Spine 📚

A beautiful iOS reading app that turns classic literature into a daily habit. Spine breaks books into bite-sized reading units, tracks your progress with a Duolingo-inspired XP system, and learns your taste to recommend what to read next — all on-device.

## Features

### 📖 EPUB Ingestion & Segmentation
- Full EPUB parser with chapter extraction and HTML normalization
- Intelligent segmentation engine splits chapters into ~10-minute reading units (1,500–3,000 words)
- Ships with 6 bundled Project Gutenberg classics

### 🔥 Habit Engine
- **Daily reading streaks** with flame badges
- **XP progression system** — earn XP for completing units, level up through 15 tiers from *Bookworm* to *Grand Librarian*
- **Reading speed tracking** with exponential moving average WPM
- **Consistency scoring** — rolling 7-day engagement metric

### 🎯 Recommendations
- Hybrid scoring engine combining genre match, vibe affinity, and NLEmbedding-based synopsis similarity
- Micro-reason feedback ("Enjoyed: Prose, Atmosphere" / "Less so: Slow, Dense") feeds back into taste profiles
- On-device `NLEmbedding` for cosine-similarity book matching — no API calls

### 🏆 Gamification
- Achievement gallery with unlock tracking
- XP toast notifications and celebration overlays
- Level progress bar with named tiers

### 📝 Engagement
- Highlight and note creation
- Post-unit reaction prompts (emoji chips + free-text reflection)
- Quote saving

### 🎨 Design
- Custom design system (`SpineTokens`) with warm, literary color palette — cream, espresso, accent gold
- Serif reader typography with light, sepia, and dark themes
- Liquid Glass card effects on iOS 26+

## Architecture

```
Spine/
├── App/              # Entry point, routing, tab bar
├── Design/           # SpineTokens design system, reusable components
├── Extensions/       # Color+Hex, utilities
├── Features/
│   ├── Gamification/ # XP bar, toasts, achievements, celebrations
│   ├── Highlights/   # Highlight list & management
│   ├── Library/      # Book grid, For You recommendations
│   ├── Onboarding/   # Genre/vibe taste selection
│   ├── Profile/      # User stats, achievements, settings
│   ├── Reactions/    # Post-reading feedback sheets
│   ├── Reader/       # EPUB reader with progress tracking
│   └── Today/        # Daily dashboard with XP, streak, next unit
├── Models/           # SwiftData models (Book, Chapter, ReadingUnit, XPProfile, etc.)
├── SeedData/         # Bundled book catalog seeding
├── Services/
│   ├── EPUBParser/   # EPUB extraction, HTML normalization
│   ├── IngestionPipeline    # End-to-end import orchestration
│   ├── RecommendationService # Hybrid scoring engine
│   ├── EmbeddingService     # NLEmbedding wrapper
│   ├── XPEngine             # XP calculation & level progression
│   ├── AchievementEngine    # Achievement unlock logic
│   ├── ProgressTracker      # Reading progress & session tracking
│   ├── SegmentationEngine   # Chapter → reading unit splitting
│   └── StreakCalculator     # Streak computation
└── Stubs/            # Feature flags, AI/Social protocol stubs
```

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI, Liquid Glass (iOS 26) |
| Data | SwiftData |
| NLP | NaturalLanguage (NLEmbedding) |
| EPUB | Custom parser + ZIPFoundation |
| Concurrency | Swift 6, `@MainActor` |
| Min Target | iOS 26 |

## Phased Roadmap

| Phase | Status | Features |
|---|---|---|
| **1 — Core Habit Engine** | ✅ Shipped | EPUB ingestion, daily segmentation, streaks, highlights, reactions, XP |
| **2 — Open Ecosystem + AI** | 🔲 Planned | Arbitrary EPUB import, define word, explain paragraph, unit recaps |
| **3 — Spoiler-Safe Intelligence** | 🔲 Planned | Progress-aware RAG, character graph, Ask the Book, X-Ray |
| **4 — Social Layer** | 🔲 Planned | Chapter-gated discussions, reading clubs, public profiles, highlight sharing |

## Getting Started

### Requirements
- Xcode 26.3+
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

## License

This project is provided as-is for portfolio and educational purposes.
