import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  // TTS API keys from .env file
  static String? get openaiApiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    return (key != null && key.isNotEmpty) ? key : null;
  }

  static String? get googleCloudApiKey {
    final key = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    return (key != null && key.isNotEmpty) ? key : null;
  }
}
