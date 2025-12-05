import 'package:hive/hive.dart';

part 'conversation_model.g.dart';

@HiveType(typeId: 0)
enum ConversationType {
  @HiveField(0)
  meeting,
  @HiveField(1)
  memo,
}

@HiveType(typeId: 1)
class AudioSegment {
  @HiveField(0)
  final String filePath;
  @HiveField(1)
  final int durationMs;

  AudioSegment({required this.filePath, required this.durationMs});

  Duration get duration => Duration(milliseconds: durationMs);
}

@HiveType(typeId: 2)
class Transcript {
  @HiveField(0)
  final String fullText;
  @HiveField(1)
  final String languageCode;

  Transcript({required this.fullText, required this.languageCode});
}

@HiveType(typeId: 3)
class AiResult {
  @HiveField(0)
  final String titleAr;
  @HiveField(1)
  final String titleEn;
  @HiveField(2)
  final String summaryAr;
  @HiveField(3)
  final String summaryEn;
  @HiveField(4)
  final List<String> bulletPointsAr;
  @HiveField(5)
  final List<String> bulletPointsEn;
  @HiveField(6)
  final List<String> todosAr;
  @HiveField(7)
  final List<String> todosEn;
  @HiveField(8)
  final List<bool> todosCompletedAr;
  @HiveField(9)
  final List<bool> todosCompletedEn;

  AiResult({
    required this.titleAr,
    required this.titleEn,
    required this.summaryAr,
    required this.summaryEn,
    required this.bulletPointsAr,
    required this.bulletPointsEn,
    required this.todosAr,
    required this.todosEn,
    List<bool>? todosCompletedAr,
    List<bool>? todosCompletedEn,
  })  : todosCompletedAr = todosCompletedAr ?? List.filled(todosAr.length, false),
        todosCompletedEn = todosCompletedEn ?? List.filled(todosEn.length, false);

  AiResult copyWith({
    String? titleAr,
    String? titleEn,
    String? summaryAr,
    String? summaryEn,
    List<String>? bulletPointsAr,
    List<String>? bulletPointsEn,
    List<String>? todosAr,
    List<String>? todosEn,
    List<bool>? todosCompletedAr,
    List<bool>? todosCompletedEn,
  }) {
    return AiResult(
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      summaryAr: summaryAr ?? this.summaryAr,
      summaryEn: summaryEn ?? this.summaryEn,
      bulletPointsAr: bulletPointsAr ?? this.bulletPointsAr,
      bulletPointsEn: bulletPointsEn ?? this.bulletPointsEn,
      todosAr: todosAr ?? this.todosAr,
      todosEn: todosEn ?? this.todosEn,
      todosCompletedAr: todosCompletedAr ?? this.todosCompletedAr,
      todosCompletedEn: todosCompletedEn ?? this.todosCompletedEn,
    );
  }
}

@HiveType(typeId: 4)
class Conversation {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final ConversationType type;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String? subtitle;
  @HiveField(4)
  final String primaryLanguage;
  @HiveField(5)
  final DateTime createdAt;
  @HiveField(6)
  final DateTime updatedAt;
  @HiveField(7)
  final List<AudioSegment> audioSegments;
  @HiveField(8)
  final Transcript? transcript;
  @HiveField(9)
  final AiResult? aiResult;
  @HiveField(10)
  final bool isStarred;
  @HiveField(11)
  final String? folderId;
  @HiveField(12)
  final List<String> tags;

  Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.primaryLanguage,
    required this.createdAt,
    required this.updatedAt,
    required this.audioSegments,
    this.transcript,
    this.aiResult,
    this.isStarred = false,
    this.folderId,
    this.tags = const [],
  });

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? title,
    String? subtitle,
    String? primaryLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AudioSegment>? audioSegments,
    Transcript? transcript,
    AiResult? aiResult,
    bool? isStarred,
    String? folderId,
    List<String>? tags,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioSegments: audioSegments ?? this.audioSegments,
      transcript: transcript ?? this.transcript,
      aiResult: aiResult ?? this.aiResult,
      isStarred: isStarred ?? this.isStarred,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
    );
  }
}
