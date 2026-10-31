# Hero Adventure · 英雄闯关计划

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Pad-lightgrey?style=for-the-badge" alt="Platform" />
</p>

A cross-platform (phone / tablet) **family habit-building app for children**. Daily chores (brushing teeth, tidying the room, going to bed on time) are wrapped into an "Ultraman vs. monsters" adventure: each check-in is a battle, each reward earns EXP and Coins, and unlocks hero cards. Local-first storage with dual-track sync (LAN / WebDAV).

> The default theme is the Ultraman universe; a multi-theme framework is reserved for future themes (mecha / magic academy).

## ✨ Highlights

- 🦸 Gamified check-ins: tasks = levels, check-ins = battles.
- 👨‍👩‍👧‍👦 Multi-child family profiles, fully isolated.
- 🔐 Parent safety PIN (4 digits) to prevent kids from editing tasks / self-rewarding.
- 📊 Parent dashboard: check-in heatmap, coin curve, approval center (photo proof + reward exchange).
- 🔄 Local-first + dual-track sync: Hive storage, LAN QR transfer, WebDAV cloud backup.
- 📱 Adaptive phone / tablet layouts.

## 🚀 Tech Stack

| Layer | Tech |
| ---- | ---- |
| UI | Flutter (one codebase → Android / iOS / Pad) |
| State | Riverpod |
| Local storage | Hive |
| Animation | lottie |
| Audio | just_audio |
| LAN sync | qr_flutter + mobile_scanner |
| Cloud sync | http (WebDAV) |
| Offline TTS | Sherpa-ONNX (Chinese VITS + English Piper, dual models) |

## ✅ Implemented Features

### Child Adventure (Ultraman theme)
- Earth defense map, check-in flow with Lottie monster-explosion.
- Hero gallery unlocked by EXP.
- Reward exchange + parent approval.
- Photo check-in.
- Math quiz (tablet split layout).
- Preset task templates.

### Child Learning Read-Along System (Offline TTS)
- Three subjects: **Pinyin / Chinese characters / English**, unified `LearnItem` word bank + `Task` config.
- **Fully offline neural TTS** (Sherpa-ONNX Chinese VITS + English Piper dual models) — **Sherpa end-to-end**, for Chinese-character / English reading, stable single-character / single-word playback with no network.
- **The Pinyin module now plays a teaching video instead of TTS**: a bundled MP4 auto-plays on entry (pause / scrub supported); finishing the video or tapping "完成学习" grants the reward. Video source: Bilibili BV1Fe411N7my (attributed in small print at the bottom of the card, tappable to open the original; removable on takedown request).
- Chinese: also reads the example word and shows its tone-marked pinyin above the word. English: also reads the Chinese meaning with IPA (American) + pinyin of the meaning.
- **Instant "Listen once"**: on page entry the app pre-synthesizes **all** read-aloud segments into cache (+ in-flight de-duplication), so tapping plays immediately; the speaker icon animates while playing / loading.
- The learning tasks (Pinyin / Chinese / English) and their check-in records are all included in the full backup (see Data Sync) — survive device switch / restore.

### Data Sync Engine
- LAN face-to-face transfer (QR generate / scan).
- WebDAV cloud sync (credentials, Last-Modified merge).
- Auto sync on app enter / exit; forced sync on key actions.
- Full backup: `.herobackup` archive (data.json + images), backup / restore — including Pinyin / Chinese / English learning tasks and check-in records.

## ⏳ Not Yet Implemented
- Richer UI transition animations.
- More Ultraman assets.
- Other themes (mecha / magic).
- More check-in sound effects.

## 🛠️ Build & Run

### Requirements
- Flutter SDK (Dart SDK ≥ 3.10.0)
- Android Studio / Xcode

### Get dependencies
```bash
flutter pub get
```

> **Offline TTS models are NOT in git**: `assets/tts_model/zh/vits-zh-hf-fanchen-C.onnx` (~116MB) and `assets/tts_model/en/en_US-libritts_r-medium.onnx` (~75MB) exceed code-hosting single-file / LFS limits, so they are not distributed with the repo. Download them and place into the matching folders (keep the already-tracked `tokens.txt` / `lexicon.txt` / `*.fst` support files) for offline pronunciation to work; the app gracefully falls back to system TTS when the models are missing. Model source: Sherpa-ONNX official model zoo (`k2-fsa/sherpa-onnx` Releases / Hugging Face `csukuangfj`).

### Run
```bash
flutter run
```

### Android release build
> ⚠️ Signing key (`android/app/hero_adventure.jks`) and `android/key.properties` are sensitive and git-ignored — do NOT commit them.

```bash
flutter build apk --release
```

## 📂 Project Structure
```
lib/
├── core/      # core utils (audio, sync, backup, native bridge, TTS)
├── data/      # data layer (Hive, models, learn_content word banks)
├── domain/    # business logic (Riverpod providers, hero system, learn_quiz)
└── features/
    ├── auth/
    ├── child_adventure/   # child side (map, gallery, shop, quiz, learn)
    ├── parent_console/    # parent console (dashboard, approval, settings)
    ├── shared/
    └── sync/              # sync engine (QR, WebDAV)
```

## 📄 License
For personal / learning use only. Respect open-source licenses and asset copyright.
