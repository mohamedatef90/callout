import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../constants/api_keys.dart';
import '../../features/conversations/data/models/conversation_model.dart';
import 'dart:convert';

part 'gemini_service.g.dart';

class GeminiService {
  late final GenerativeModel _model;
  late final GenerativeModel _audioModel;

  GeminiService() {
    // Use gemini-2.5-flash for both text and audio (supports multimodal input)
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiKeys.googleApiKey,
    );
    // Use same model for audio transcription
    _audioModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiKeys.googleApiKey,
    );
  }

  Future<String> transcribeAudio(String audioPath) async {
    final audioFile = File(audioPath);
    final audioBytes = await audioFile.readAsBytes();

    // Determine mime type based on file extension
    final extension = audioPath.split('.').last.toLowerCase();
    String mimeType;
    switch (extension) {
      case 'm4a':
        mimeType = 'audio/mp4';
        break;
      case 'mp3':
        mimeType = 'audio/mpeg';
        break;
      case 'wav':
        mimeType = 'audio/wav';
        break;
      case 'aac':
        mimeType = 'audio/aac';
        break;
      default:
        mimeType = 'audio/mp4';
    }

    final prompt = TextPart(
      "Transcribe this audio file accurately. The audio may contain Egyptian Arabic and English. Return only the transcription text, nothing else.",
    );
    final audioPart = DataPart(mimeType, audioBytes);

    final response = await _audioModel.generateContent([
      Content.multi([prompt, audioPart]),
    ]);

    return response.text ?? '';
  }

  Future<AiResult> generateSummary(String transcript) async {
    final prompt =
        '''
      You are an AI assistant that analyzes transcripts of meetings and memos in Egyptian Arabic and English (often mixed).
      Given the following transcript, generate a JSON object with:
      - title_ar: short, clear Arabic title
      - title_en: short, clear English title
      - summary_ar: 3–6 sentences summarizing in Arabic
      - summary_en: 3–6 sentences summarizing in English
      - bullet_points_ar: list of concise Arabic bullet points
      - bullet_points_en: list of concise English bullet points
      - todos_ar: list of actionable Arabic to-dos
      - todos_en: list of actionable English to-dos

      Respond ONLY with valid JSON. Do not include explanations or markdown formatting like ```json.

      Transcript:
      $transcript
    ''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text =
        response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ??
        '{}';

    try {
      final json = jsonDecode(text);
      return AiResult(
        titleAr: json['title_ar'] ?? '',
        titleEn: json['title_en'] ?? '',
        summaryAr: json['summary_ar'] ?? '',
        summaryEn: json['summary_en'] ?? '',
        bulletPointsAr: List<String>.from(json['bullet_points_ar'] ?? []),
        bulletPointsEn: List<String>.from(json['bullet_points_en'] ?? []),
        todosAr: List<String>.from(json['todos_ar'] ?? []),
        todosEn: List<String>.from(json['todos_en'] ?? []),
      );
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e');
    }
  }

  /// Supported languages for translation
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'pl', 'name': 'Polish'},
  ];

  /// Translate text to target language using Google AI
  Future<String> translateText(String text, String targetLanguage) async {
    if (text.isEmpty) return '';

    final prompt = '''
Translate the following text to $targetLanguage.
Return ONLY the translated text, nothing else.
Preserve the original formatting, line breaks, and structure.

Text to translate:
$text
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? text;
  }

  /// Translate with context for better accuracy
  Future<String> translateWithContext(
    String text,
    String targetLanguage, {
    String? context,
  }) async {
    if (text.isEmpty) return '';

    final contextInfo = context != null
        ? '\nContext: This is from a $context.'
        : '';

    final prompt = '''
You are a professional translator. Translate the following text to $targetLanguage.
Return ONLY the translated text, nothing else.
Preserve the original formatting, line breaks, bullet points, and structure.$contextInfo

Text to translate:
$text
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? text;
  }
}

@Riverpod(keepAlive: true)
GeminiService geminiService(GeminiServiceRef ref) {
  return GeminiService();
}
