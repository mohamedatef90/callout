# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Callout is a Flutter mobile app for recording audio (Egyptian Arabic + English), transcribing via Google Gemini, and generating AI-powered summaries, bullet points, and to-do lists. All data is stored locally on the device.

**Key constraints:**
- No external backend - all data persists locally using Hive
- Remote calls only to Google Gemini API for transcription and AI processing
- Supports bilingual content (Arabic + English) with code-switching
- Target platforms: Android & iOS

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build apk          # Android
flutter build ios          # iOS

# Generate Hive adapters and Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze

# Run tests
flutter test

# Generate app icons (after changing assets/calllout.jpg)
dart run flutter_launcher_icons
```

## Architecture

The app follows a feature-based clean architecture pattern:

```
lib/
├── main.dart                    # App entry, initializes Hive and Riverpod
├── core/
│   ├── constants/api_keys.dart  # Google API key (loaded from .env via flutter_dotenv)
│   ├── services/
│   │   ├── audio_recorder_service.dart  # Audio recording using `record` package
│   │   ├── gemini_service.dart          # Gemini API: transcription + AI summaries
│   │   └── storage_service.dart         # Hive initialization and box management
│   └── utils/formatters.dart
└── features/conversations/
    ├── data/
    │   ├── models/conversation_model.dart  # Hive models: Conversation, AudioSegment, Transcript, AiResult
    │   └── repositories/conversation_repository.dart
    └── presentation/
        ├── providers/           # Riverpod providers (with riverpod_generator)
        ├── screens/
        │   ├── home_screen.dart      # Main list of conversations
        │   ├── recording_screen.dart # Audio recording UI with waveform
        │   └── detail_screen.dart    # Conversation details (summary, bullets, todos, transcript)
        └── widgets/
```

## Key Technologies

- **State Management**: Riverpod with `riverpod_generator` annotations
- **Local Storage**: Hive (conversations, transcripts, AI results)
- **Audio Recording**: `record` package (saves as .m4a)
- **AI Integration**: `google_generative_ai` package with Gemini 1.5 Flash
- **API Keys**: Stored in `.env` file, loaded via `flutter_dotenv`

## Data Models

Core entities in `lib/features/conversations/data/models/conversation_model.dart`:
- `Conversation` - Main entity with audio segments, transcript, and AI results
- `ConversationType` - `meeting` or `memo`
- `AudioSegment` - Audio file path and duration
- `Transcript` - Full text and language code
- `AiResult` - Bilingual title, summary, bullet points, and todos (Arabic + English)

## Gemini Integration

The `GeminiService` handles two operations:
1. **Audio Transcription** - Sends audio file to Gemini for transcription (handles Arabic/English mix)
2. **AI Summary Generation** - Sends transcript, receives structured JSON with bilingual outputs

Prompts must explicitly handle Egyptian Arabic mixed with English and request bilingual JSON responses.

## Environment Setup

Create a `.env` file in the project root:
```
GOOGLE_API_KEY=your_gemini_api_key_here
```

The key is accessed via `ApiKeys.googleApiKey` in `lib/core/constants/api_keys.dart`.
