# Callout

A Flutter voice-recording app with AI-powered transcription and meeting summaries, designed for capturing conversations and turning them into useful notes.

## What it demonstrates

- Cross-platform Flutter product development
- Voice recording and audio playback
- Background recording on Android and iOS
- AI-assisted transcription and summarization
- Local conversation storage (Hive)
- Conversation reminders and device calendar integration
- Text-to-speech playback (device voice or Gemini) and sharing of conversation content
- Recording-state notifications and lifecycle handling
- Mobile-first interaction and branding

## Background recording

Callout uses an Android foreground service and iOS background-audio mode so recordings can continue when the app is backgrounded or the screen is locked. See [`BACKGROUND_RECORDING.md`](BACKGROUND_RECORDING.md) for implementation details and platform caveats.

## Tech stack

- Flutter and Dart
- Riverpod
- Hive
- Google Generative AI
- `record`, `just_audio`, and `audioplayers`
- Local notifications and device calendar integrations

## Run locally

```bash
flutter pub get
cp .env.example .env     # then set GOOGLE_API_KEY
flutter run
```

`.env` is loaded at startup and is declared as an asset in `pubspec.yaml`, so the file must exist for the app to build and run. Do not commit credentials or production API keys.

### Environment variables

Set in `.env` (name only; also listed in `.env.example`):

- `GOOGLE_API_KEY`: Gemini API key, used for transcription and summaries (model `gemini-2.5-flash`) and for Gemini text-to-speech.

`lib/core/constants/api_keys.dart` also defines optional `OPENAI_API_KEY` and `GOOGLE_CLOUD_API_KEY` getters, but no other code reads them.

## Quality checks

```bash
flutter analyze
flutter test
```

Background recording should be tested on physical Android and iOS devices; simulators do not reliably reproduce platform background behavior.

## Documentation

- [`BACKGROUND_RECORDING.md`](BACKGROUND_RECORDING.md)
- [`BRANDING.md`](BRANDING.md)

## Status

Product prototype. Before production release, complete device testing, privacy and consent flows, secure key management, retention controls, and platform-store compliance review for audio recording.
