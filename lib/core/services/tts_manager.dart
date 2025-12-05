import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'tts_providers/tts_provider_interface.dart';
import 'tts_providers/device_tts_provider.dart';
import 'tts_providers/openai_tts_provider.dart';
import 'tts_providers/google_cloud_tts_provider.dart';
import '../constants/api_keys.dart';

part 'tts_manager.g.dart';

/// TTS Manager that handles provider switching and speech playback
class TtsManager extends ChangeNotifier {
  TtsProviderInterface? _currentProvider;
  TtsProviderType _currentProviderType = TtsProviderType.device;

  TtsState get state => _currentProvider?.state ?? TtsState.idle;
  bool get isPlaying => _currentProvider?.isPlaying ?? false;
  String? get errorMessage => _currentProvider?.errorMessage;
  TtsProviderType get currentProviderType => _currentProviderType;

  TtsManager() {
    // Initialize with device TTS by default
    _initializeProvider(TtsProviderType.device);
  }

  /// Set the TTS provider type
  Future<void> setProvider(TtsProviderType providerType) async {
    if (providerType == _currentProviderType) {
      return;
    }

    // Stop current provider
    await _currentProvider?.stop();
    _currentProvider?.dispose();

    await _initializeProvider(providerType);
  }

  Future<void> _initializeProvider(TtsProviderType providerType) async {
    _currentProviderType = providerType;

    switch (providerType) {
      case TtsProviderType.device:
        _currentProvider = DeviceTtsProvider();
        break;
      case TtsProviderType.openai:
        final apiKey = ApiKeys.openaiApiKey;
        if (apiKey == null || apiKey.isEmpty) {
          debugPrint('TtsManager: OpenAI API key not set in .env, falling back to device');
          _currentProvider = DeviceTtsProvider();
          _currentProviderType = TtsProviderType.device;
        } else {
          debugPrint('TtsManager: Using OpenAI API key from .env');
          _currentProvider = OpenAiTtsProvider(apiKey: apiKey);
        }
        break;
      case TtsProviderType.googleCloud:
        final apiKey = ApiKeys.googleCloudApiKey;
        if (apiKey == null || apiKey.isEmpty) {
          debugPrint('TtsManager: Google Cloud API key not set in .env, falling back to device');
          _currentProvider = DeviceTtsProvider();
          _currentProviderType = TtsProviderType.device;
        } else {
          debugPrint('TtsManager: Using Google Cloud API key from .env');
          _currentProvider = GoogleCloudTtsProvider(apiKey: apiKey);
        }
        break;
    }

    // Forward notifications from the provider
    _currentProvider?.addListener(() {
      notifyListeners();
    });

    await _currentProvider?.initialize();
    debugPrint('TtsManager: Initialized with provider ${_currentProviderType.name}');
    notifyListeners();
  }

  /// Speak text using the current provider
  Future<void> speak(String text, {String language = 'en'}) async {
    if (_currentProvider == null) {
      await _initializeProvider(_currentProviderType);
    }

    try {
      await _currentProvider?.speak(text, language: language);
    } catch (e) {
      debugPrint('TtsManager speak error: $e');
      rethrow;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    await _currentProvider?.stop();
  }

  /// Test the current provider with a sample text
  Future<void> testProvider({String language = 'en'}) async {
    final testText = language == 'ar'
        ? 'مرحبا، هذا اختبار للنطق.'
        : 'Hello, this is a speech test.';
    await speak(testText, language: language);
  }

  @override
  void dispose() {
    _currentProvider?.dispose();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
TtsManager ttsManager(TtsManagerRef ref) {
  final manager = TtsManager();
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
}
