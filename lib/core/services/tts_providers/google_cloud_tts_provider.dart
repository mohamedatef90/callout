import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'tts_provider_interface.dart';

/// Google Cloud TTS voice types
enum GoogleCloudVoiceType {
  standard,
  wavenet,
  neural2,
}

/// Google Cloud TTS provider using Google Cloud Text-to-Speech API
class GoogleCloudTtsProvider extends TtsProviderInterface {
  final String apiKey;
  final GoogleCloudVoiceType voiceType;

  final AudioPlayer _audioPlayer = AudioPlayer();
  TtsState _state = TtsState.idle;
  String? _errorMessage;
  bool _isInitialized = false;

  GoogleCloudTtsProvider({
    required this.apiKey,
    this.voiceType = GoogleCloudVoiceType.neural2,
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
          debugPrint('Google Cloud TTS: Playback completed');
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
      debugPrint('Google Cloud TTS: Initialized successfully');
    } catch (e) {
      debugPrint('Google Cloud TTS init error: $e');
      _state = TtsState.error;
      _errorMessage = 'Failed to initialize Google Cloud TTS: $e';
    }
  }

  @override
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) {
      debugPrint('Google Cloud TTS: Empty text, skipping');
      return;
    }

    if (apiKey.isEmpty) {
      throw Exception('Google Cloud API key is required');
    }

    if (!_isInitialized) {
      await initialize();
    }

    await stop();

    try {
      debugPrint('Google Cloud TTS: Generating speech for ${text.length} chars');
      _state = TtsState.playing;
      _errorMessage = null;
      notifyListeners();

      // Get voice name based on language and voice type
      final voiceConfig = _getVoiceConfig(language);

      // Call Google Cloud TTS API
      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': voiceConfig['languageCode'],
            'name': voiceConfig['name'],
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
            'pitch': 0.0,
          },
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = response.body;
        debugPrint('Google Cloud TTS Error: ${response.statusCode} - $errorBody');
        throw Exception('Google Cloud TTS API error: ${response.statusCode}');
      }

      final responseJson = jsonDecode(response.body);
      final audioContent = responseJson['audioContent'] as String;
      final audioBytes = base64Decode(audioContent);

      debugPrint('Google Cloud TTS: Received ${audioBytes.length} bytes');

      // Save audio to temp file and play
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/google_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(audioBytes);

      debugPrint('Google Cloud TTS: Playing audio from ${tempFile.path}');
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
        debugPrint('Google Cloud TTS: Could not delete temp file: $e');
      }

      _state = TtsState.idle;
      notifyListeners();
      debugPrint('Google Cloud TTS: Speech completed');
    } catch (e) {
      debugPrint('Google Cloud TTS speak error: $e');
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
      debugPrint('Google Cloud TTS: Stopped');
    } catch (e) {
      debugPrint('Google Cloud TTS stop error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Get voice configuration based on language and voice type
  Map<String, String> _getVoiceConfig(String language) {
    final voicePrefix = _getVoicePrefix();

    if (language == 'ar') {
      // Arabic voices (ar-XA)
      return {
        'languageCode': 'ar-XA',
        'name': 'ar-XA-$voicePrefix-A', // Female voice
      };
    } else {
      // English voices (en-US)
      return {
        'languageCode': 'en-US',
        'name': 'en-US-$voicePrefix-A', // Female voice
      };
    }
  }

  /// Get voice prefix based on voice type
  String _getVoicePrefix() {
    switch (voiceType) {
      case GoogleCloudVoiceType.standard:
        return 'Standard';
      case GoogleCloudVoiceType.wavenet:
        return 'Wavenet';
      case GoogleCloudVoiceType.neural2:
        return 'Neural2';
    }
  }
}
