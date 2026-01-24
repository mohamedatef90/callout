import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'tts_provider_interface.dart';

/// Google AI TTS provider using Gemini 2.5 Flash TTS API
/// Uses the same GOOGLE_API_KEY as transcription
class GoogleAiTtsProvider extends TtsProviderInterface {
  final String apiKey;

  final AudioPlayer _audioPlayer = AudioPlayer();
  TtsState _state = TtsState.idle;
  String? _errorMessage;
  bool _isInitialized = false;

  GoogleAiTtsProvider({required this.apiKey});

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
      _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          debugPrint('Google AI TTS: Playback completed');
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
      debugPrint('Google AI TTS: Initialized successfully');
    } catch (e) {
      debugPrint('Google AI TTS init error: $e');
      _state = TtsState.error;
      _errorMessage = 'Failed to initialize Google AI TTS: $e';
    }
  }

  @override
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) {
      debugPrint('Google AI TTS: Empty text, skipping');
      return;
    }

    if (apiKey.isEmpty) {
      throw Exception('Google AI API key is required');
    }

    if (!_isInitialized) {
      await initialize();
    }

    await stop();

    try {
      debugPrint('Google AI TTS: Generating speech for ${text.length} chars in $language');
      _state = TtsState.playing;
      _errorMessage = null;
      notifyListeners();

      // Select voice based on language
      // Available voices: Aoede, Charon, Fenrir, Kore, Puck, Zephyr, Leda, Orus, etc.
      // Kore - good for English, Aoede - good for multiple languages including Arabic
      final voiceName = language == 'ar' ? 'Aoede' : 'Kore';

      final audioBytes = await _generateSpeech(text, voiceName, language);

      if (audioBytes == null || audioBytes.isEmpty) {
        throw Exception('Failed to generate audio');
      }

      debugPrint('Google AI TTS: Received ${audioBytes.length} bytes of PCM data');

      // Convert raw PCM to WAV (Gemini returns 24kHz, 16-bit, mono PCM)
      final wavBytes = _pcmToWav(audioBytes, sampleRate: 24000, channels: 1, bitsPerSample: 16);

      // Save audio to temp file and play
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/gemini_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes);

      debugPrint('Google AI TTS: Playing audio from ${tempFile.path}');
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
        debugPrint('Google AI TTS: Could not delete temp file: $e');
      }

      _state = TtsState.idle;
      notifyListeners();
      debugPrint('Google AI TTS: Speech completed');
    } catch (e) {
      debugPrint('Google AI TTS speak error: $e');
      _state = TtsState.error;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Convert raw PCM data to WAV format
  Uint8List _pcmToWav(Uint8List pcmData, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final wavData = BytesBuilder();

    // RIFF header
    wavData.add(utf8.encode('RIFF'));
    wavData.add(_int32ToBytes(fileSize));
    wavData.add(utf8.encode('WAVE'));

    // fmt subchunk
    wavData.add(utf8.encode('fmt '));
    wavData.add(_int32ToBytes(16)); // Subchunk1 size
    wavData.add(_int16ToBytes(1));  // Audio format (1 = PCM)
    wavData.add(_int16ToBytes(channels));
    wavData.add(_int32ToBytes(sampleRate));
    wavData.add(_int32ToBytes(byteRate));
    wavData.add(_int16ToBytes(blockAlign));
    wavData.add(_int16ToBytes(bitsPerSample));

    // data subchunk
    wavData.add(utf8.encode('data'));
    wavData.add(_int32ToBytes(dataSize));
    wavData.add(pcmData);

    return wavData.toBytes();
  }

  Uint8List _int16ToBytes(int value) {
    return Uint8List(2)
      ..buffer.asByteData().setInt16(0, value, Endian.little);
  }

  Uint8List _int32ToBytes(int value) {
    return Uint8List(4)
      ..buffer.asByteData().setInt32(0, value, Endian.little);
  }

  /// Generate speech using Gemini 2.5 Flash TTS API
  Future<Uint8List?> _generateSpeech(String text, String voiceName, String language) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$apiKey'
      );

      // Clean and prepare text - remove any problematic characters
      var cleanText = text
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ') // Remove control characters
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      if (cleanText.isEmpty) {
        throw Exception('Text is empty after cleaning');
      }

      // Limit text length (TTS has limits, typically around 5000 chars)
      if (cleanText.length > 4000) {
        cleanText = cleanText.substring(0, 4000);
        debugPrint('Google AI TTS: Text truncated to 4000 characters');
      }

      // Just send the text directly - the model will speak it
      final prompt = cleanText;

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceName
              }
            }
          }
        }
      };

      debugPrint('Google AI TTS: Calling API with voice $voiceName');
      debugPrint('Google AI TTS: Text length: ${cleanText.length}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('Google AI TTS: Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = response.body;
        debugPrint('Google AI TTS API error: ${response.statusCode} - $errorBody');

        // Parse error message
        try {
          final errorJson = jsonDecode(errorBody);
          final errorMessage = errorJson['error']?['message'] ?? 'Unknown error';
          throw Exception('API error: $errorMessage');
        } catch (e) {
          throw Exception('API error: ${response.statusCode}');
        }
      }

      final json = jsonDecode(response.body);

      // Extract audio from response
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('Google AI TTS: No candidates in response');
        debugPrint('Google AI TTS: Full response: ${response.body}');
        throw Exception('No audio generated');
      }

      final content = candidates[0]['content'];
      if (content == null) {
        throw Exception('No content in response');
      }

      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('No parts in response');
      }

      for (final part in parts) {
        final inlineData = part['inlineData'];
        if (inlineData != null) {
          final mimeType = inlineData['mimeType'] as String?;
          final data = inlineData['data'] as String?;

          debugPrint('Google AI TTS: Got data with mimeType: $mimeType');

          if (data != null && data.isNotEmpty) {
            return base64Decode(data);
          }
        }
      }

      debugPrint('Google AI TTS: No audio data found in parts');
      throw Exception('No audio data in response');
    } catch (e) {
      debugPrint('Google AI TTS API call error: $e');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _state = TtsState.idle;
      notifyListeners();
      debugPrint('Google AI TTS: Stopped');
    } catch (e) {
      debugPrint('Google AI TTS stop error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
