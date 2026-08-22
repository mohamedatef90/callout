# Callout

A Flutter voice-recording app with AI-powered transcription and meeting summaries, designed for capturing conversations and turning them into useful notes.

## What it demonstrates

- Cross-platform Flutter product development
- Voice recording and audio playback
- Background recording on Android and iOS
- AI-assisted transcription and summarization
- Local conversation storage
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
flutter run
```

Create a local `.env` file for required development configuration. Do not commit credentials or production API keys.

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
