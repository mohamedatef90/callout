import 'package:flutter/foundation.dart';

/// TTS provider types
enum TtsProviderType {
  device,    // Free - uses flutter_tts
  googleAi,  // Google AI (Gemini) TTS API
}

/// TTS playback state
enum TtsState { idle, playing, paused, error }

/// Abstract interface for TTS providers
abstract class TtsProviderInterface extends ChangeNotifier {
  TtsState get state;
  bool get isPlaying;
  String? get errorMessage;

  /// Speak the given text in the specified language
  Future<void> speak(String text, {String language = 'en'});

  /// Stop current speech
  Future<void> stop();

  /// Initialize the provider (if needed)
  Future<void> initialize();

  /// Clean up resources
  @override
  void dispose();
}
