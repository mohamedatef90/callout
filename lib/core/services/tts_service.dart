import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_service.g.dart';

enum TtsState { idle, playing, paused, error }

class TtsService extends ChangeNotifier {
  FlutterTts? _flutterTts;
  TtsState _state = TtsState.idle;
  String? _errorMessage;
  bool _isInitialized = false;
  Completer<void>? _speakCompleter;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  String? get errorMessage => _errorMessage;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts = FlutterTts();

      // CRITICAL: Set awaitSpeakCompletion FIRST before any other config
      // This makes speak() actually wait for completion
      await _flutterTts!.awaitSpeakCompletion(true);

      if (Platform.isIOS) {
        await _flutterTts!.setSharedInstance(true);
        await _flutterTts!.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      // Set default values - slightly slower for better clarity
      await _flutterTts!.setSpeechRate(Platform.isIOS ? 0.5 : 0.5);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      // Setup handlers
      _flutterTts!.setStartHandler(() {
        debugPrint('TTS: Started speaking');
        _state = TtsState.playing;
        notifyListeners();
      });

      _flutterTts!.setCompletionHandler(() {
        debugPrint('TTS: Completed');
        _state = TtsState.idle;
        _speakCompleter?.complete();
        _speakCompleter = null;
        notifyListeners();
      });

      _flutterTts!.setCancelHandler(() {
        debugPrint('TTS: Cancelled');
        _state = TtsState.idle;
        _speakCompleter?.complete();
        _speakCompleter = null;
        notifyListeners();
      });

      _flutterTts!.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _state = TtsState.error;
        _errorMessage = msg.toString();
        _speakCompleter?.completeError(Exception(msg));
        _speakCompleter = null;
        notifyListeners();
      });

      // iOS specific progress handler
      if (Platform.isIOS) {
        _flutterTts!.setProgressHandler((text, start, end, word) {
          debugPrint('TTS Progress: word="$word" ($start-$end)');
        });
      }

      // Check available languages
      final languages = await _flutterTts!.getLanguages;
      debugPrint('TTS Available languages: $languages');

      // Check available voices
      final voices = await _flutterTts!.getVoices;
      debugPrint('TTS Available voices count: ${(voices as List).length}');

      // Test if TTS engine is available
      final isAvailable = await _flutterTts!.isLanguageAvailable('en-US');
      debugPrint('TTS English available: $isAvailable');

      _isInitialized = true;
      debugPrint('TTS: Initialized successfully');

    } catch (e) {
      debugPrint('TTS init error: $e');
      _state = TtsState.error;
      _errorMessage = 'Failed to initialize TTS: $e';
    }
  }

  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) {
      debugPrint('TTS: Empty text, skipping');
      return;
    }

    // Wait for initialization with retry
    int retryCount = 0;
    while (!_isInitialized && retryCount < 10) {
      debugPrint('TTS: Waiting for initialization... (attempt ${retryCount + 1})');
      await Future.delayed(const Duration(milliseconds: 200));
      retryCount++;
    }

    if (!_isInitialized) {
      debugPrint('TTS: Still not initialized after retries');
      throw Exception('TTS not initialized after waiting');
    }

    if (_flutterTts == null) {
      debugPrint('TTS: FlutterTts instance is null');
      throw Exception('TTS engine not available');
    }

    // Stop any current speech
    await stop();

    try {
      // Set language based on input
      String langCode;
      if (language == 'ar') {
        // Try different Arabic variants
        final languages = await _flutterTts!.getLanguages as List;
        debugPrint('TTS: Available Arabic languages: ${languages.where((l) => l.toString().contains('ar')).toList()}');

        if (languages.contains('ar-SA')) {
          langCode = 'ar-SA';
        } else if (languages.contains('ar-001')) {
          langCode = 'ar-001';
        } else if (languages.contains('ar')) {
          langCode = 'ar';
        } else {
          // Find any Arabic variant
          final arabicLang = languages.firstWhere(
            (l) => l.toString().toLowerCase().startsWith('ar'),
            orElse: () => 'ar-SA',
          );
          langCode = arabicLang.toString();
        }
      } else {
        // English
        langCode = 'en-US';
      }

      debugPrint('TTS: Setting language to $langCode');
      final langResult = await _flutterTts!.setLanguage(langCode);
      debugPrint('TTS: Language set result: $langResult');

      // Check if language is available
      final isLangAvailable = await _flutterTts!.isLanguageAvailable(langCode);
      debugPrint('TTS: Language $langCode available: $isLangAvailable');

      // For Arabic, try to get a specific voice
      if (language == 'ar') {
        try {
          final voices = await _flutterTts!.getVoices as List;
          final arabicVoice = voices.firstWhere(
            (v) => v['locale']?.toString().startsWith('ar') == true,
            orElse: () => <String, dynamic>{},
          );
          if (arabicVoice.isNotEmpty) {
            debugPrint('TTS: Using Arabic voice: $arabicVoice');
            await _flutterTts!.setVoice({
              'name': arabicVoice['name'],
              'locale': arabicVoice['locale'],
            });
          }
        } catch (e) {
          debugPrint('TTS: Could not set Arabic voice: $e');
        }
      }

      final textPreview = text.length > 100 ? '${text.substring(0, 100)}...' : text;
      debugPrint('TTS: Speaking text (${text.length} chars): "$textPreview"');

      _state = TtsState.playing;
      _errorMessage = null;
      notifyListeners();

      // Create completer for tracking completion
      _speakCompleter = Completer<void>();

      final result = await _flutterTts!.speak(text);
      debugPrint('TTS: Speak queued, result: $result');

      if (result != 1) {
        _state = TtsState.error;
        _errorMessage = 'TTS failed to queue speech (result=$result)';
        _speakCompleter?.completeError(Exception(_errorMessage));
        _speakCompleter = null;
        notifyListeners();
        throw Exception(_errorMessage);
      }

      // Wait for speech to complete (handlers will complete the completer)
      debugPrint('TTS: Waiting for speech to complete...');
      await _speakCompleter?.future;
      debugPrint('TTS: Speech finished');

    } catch (e) {
      debugPrint('TTS speak error: $e');
      _state = TtsState.error;
      _errorMessage = e.toString();
      _speakCompleter = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_flutterTts == null) return;

    try {
      // Complete any pending completer
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
        _speakCompleter = null;
      }

      final result = await _flutterTts!.stop();
      debugPrint('TTS: Stop result: $result');
      _state = TtsState.idle;
      notifyListeners();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
TtsService ttsService(TtsServiceRef ref) {
  final service = TtsService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}
