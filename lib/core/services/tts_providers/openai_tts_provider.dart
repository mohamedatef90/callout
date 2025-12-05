import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'tts_provider_interface.dart';

/// OpenAI TTS voice options
enum OpenAiVoice {
  alloy,    // Neutral, balanced
  echo,     // Male, warm
  fable,    // British, expressive
  onyx,     // Deep male
  nova,     // Female, friendly
  shimmer,  // Female, clear
}

/// OpenAI TTS provider using OpenAI's Text-to-Speech API
class OpenAiTtsProvider extends TtsProviderInterface {
  final String apiKey;
  final OpenAiVoice voice;
  final bool useHd;

  final AudioPlayer _audioPlayer = AudioPlayer();
  TtsState _state = TtsState.idle;
  String? _errorMessage;
  bool _isInitialized = false;

  OpenAiTtsProvider({
    required this.apiKey,
    this.voice = OpenAiVoice.alloy,
    this.useHd = false,
  });

  @override
  TtsState get state => _state;

  @override
  bool get isPlaying => _state == TtsState.playing;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Setup audio player listeners
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          debugPrint('OpenAI TTS: Playback completed');
          _state = TtsState.idle;
          notifyListeners();
        }
      });

      _audioPlayer.playingStream.listen((isPlaying) {
        if (isPlaying) {
          _state = TtsState.playing;
          notifyListeners();
        }
      });

      _isInitialized = true;
      debugPrint('OpenAI TTS: Initialized successfully');
    } catch (e) {
      debugPrint('OpenAI TTS init error: $e');
      _state = TtsState.error;
      _errorMessage = 'Failed to initialize OpenAI TTS: $e';
    }
  }

  @override
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) {
      debugPrint('OpenAI TTS: Empty text, skipping');
      return;
    }

    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key is required');
    }

    if (!_isInitialized) {
      await initialize();
    }

    await stop();

    try {
      debugPrint('OpenAI TTS: Generating speech for ${text.length} chars');
      _state = TtsState.playing;
      _errorMessage = null;
      notifyListeners();

      // Call OpenAI TTS API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: '''
{
  "model": "${useHd ? 'tts-1-hd' : 'tts-1'}",
  "input": ${_jsonEncode(text)},
  "voice": "${voice.name}",
  "response_format": "mp3"
}
''',
      );

      if (response.statusCode != 200) {
        final errorBody = response.body;
        debugPrint('OpenAI TTS Error: ${response.statusCode} - $errorBody');
        throw Exception('OpenAI TTS API error: ${response.statusCode}');
      }

      debugPrint('OpenAI TTS: Received ${response.bodyBytes.length} bytes');

      // Save audio to temp file and play
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/openai_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(response.bodyBytes);

      debugPrint('OpenAI TTS: Playing audio from ${tempFile.path}');
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();

      // Wait for playback to complete
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('OpenAI TTS: Could not delete temp file: $e');
      }

      _state = TtsState.idle;
      notifyListeners();
      debugPrint('OpenAI TTS: Speech completed');
    } catch (e) {
      debugPrint('OpenAI TTS speak error: $e');
      _state = TtsState.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _state = TtsState.idle;
      notifyListeners();
      debugPrint('OpenAI TTS: Stopped');
    } catch (e) {
      debugPrint('OpenAI TTS stop error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Properly encode text for JSON
  String _jsonEncode(String text) {
    return '"${text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t')}"';
  }
}
