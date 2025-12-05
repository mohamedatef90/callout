import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_provider_interface.dart';

/// Device TTS provider using flutter_tts (free, uses device's built-in TTS)
class DeviceTtsProvider extends TtsProviderInterface {
  FlutterTts? _flutterTts;
  TtsState _state = TtsState.idle;
  String? _errorMessage;
  bool _isInitialized = false;
  Completer<void>? _speakCompleter;

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
      _flutterTts = FlutterTts();

      // Set awaitSpeakCompletion for proper async behavior
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

      await _flutterTts!.setSpeechRate(Platform.isIOS ? 0.5 : 0.5);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      // Setup handlers
      _flutterTts!.setStartHandler(() {
        debugPrint('DeviceTTS: Started speaking');
        _state = TtsState.playing;
        notifyListeners();
      });

      _flutterTts!.setCompletionHandler(() {
        debugPrint('DeviceTTS: Completed');
        _state = TtsState.idle;
        _speakCompleter?.complete();
        _speakCompleter = null;
        notifyListeners();
      });

      _flutterTts!.setCancelHandler(() {
        debugPrint('DeviceTTS: Cancelled');
        _state = TtsState.idle;
        _speakCompleter?.complete();
        _speakCompleter = null;
        notifyListeners();
      });

      _flutterTts!.setErrorHandler((msg) {
        debugPrint('DeviceTTS Error: $msg');
        _state = TtsState.error;
        _errorMessage = msg.toString();
        _speakCompleter?.completeError(Exception(msg));
        _speakCompleter = null;
        notifyListeners();
      });

      if (Platform.isIOS) {
        _flutterTts!.setProgressHandler((text, start, end, word) {
          debugPrint('DeviceTTS Progress: word="$word" ($start-$end)');
        });
      }

      final languages = await _flutterTts!.getLanguages;
      debugPrint('DeviceTTS Available languages: $languages');

      _isInitialized = true;
      debugPrint('DeviceTTS: Initialized successfully');
    } catch (e) {
      debugPrint('DeviceTTS init error: $e');
      _state = TtsState.error;
      _errorMessage = 'Failed to initialize Device TTS: $e';
    }
  }

  @override
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) {
      debugPrint('DeviceTTS: Empty text, skipping');
      return;
    }

    // Ensure initialized
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        throw Exception('DeviceTTS not initialized');
      }
    }

    if (_flutterTts == null) {
      throw Exception('DeviceTTS engine not available');
    }

    await stop();

    try {
      // Set language based on input
      String langCode;
      if (language == 'ar') {
        final languages = await _flutterTts!.getLanguages as List;
        if (languages.contains('ar-SA')) {
          langCode = 'ar-SA';
        } else if (languages.contains('ar-001')) {
          langCode = 'ar-001';
        } else if (languages.contains('ar')) {
          langCode = 'ar';
        } else {
          final arabicLang = languages.firstWhere(
            (l) => l.toString().toLowerCase().startsWith('ar'),
            orElse: () => 'ar-SA',
          );
          langCode = arabicLang.toString();
        }
      } else {
        langCode = 'en-US';
      }

      debugPrint('DeviceTTS: Setting language to $langCode');
      await _flutterTts!.setLanguage(langCode);

      // For Arabic, try to get a specific voice
      if (language == 'ar') {
        try {
          final voices = await _flutterTts!.getVoices as List;
          final arabicVoice = voices.firstWhere(
            (v) => v['locale']?.toString().startsWith('ar') == true,
            orElse: () => <String, dynamic>{},
          );
          if (arabicVoice.isNotEmpty) {
            await _flutterTts!.setVoice({
              'name': arabicVoice['name'],
              'locale': arabicVoice['locale'],
            });
          }
        } catch (e) {
          debugPrint('DeviceTTS: Could not set Arabic voice: $e');
        }
      }

      final textPreview = text.length > 100 ? '${text.substring(0, 100)}...' : text;
      debugPrint('DeviceTTS: Speaking text (${text.length} chars): "$textPreview"');

      _state = TtsState.playing;
      _errorMessage = null;
      notifyListeners();

      _speakCompleter = Completer<void>();

      final result = await _flutterTts!.speak(text);
      debugPrint('DeviceTTS: Speak queued, result: $result');

      if (result != 1) {
        _state = TtsState.error;
        _errorMessage = 'DeviceTTS failed to queue speech (result=$result)';
        _speakCompleter?.completeError(Exception(_errorMessage));
        _speakCompleter = null;
        notifyListeners();
        throw Exception(_errorMessage);
      }

      await _speakCompleter?.future;
      debugPrint('DeviceTTS: Speech finished');
    } catch (e) {
      debugPrint('DeviceTTS speak error: $e');
      _state = TtsState.error;
      _errorMessage = e.toString();
      _speakCompleter = null;
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (_flutterTts == null) return;

    try {
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete();
        _speakCompleter = null;
      }

      final result = await _flutterTts!.stop();
      debugPrint('DeviceTTS: Stop result: $result');
      _state = TtsState.idle;
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceTTS stop error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    super.dispose();
  }
}
