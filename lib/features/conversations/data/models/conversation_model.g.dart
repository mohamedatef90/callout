// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioSegmentAdapter extends TypeAdapter<AudioSegment> {
  @override
  final int typeId = 1;

  @override
  AudioSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioSegment(
      filePath: fields[0] as String,
      durationMs: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AudioSegment obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.durationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranscriptAdapter extends TypeAdapter<Transcript> {
  @override
  final int typeId = 2;

  @override
  Transcript read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transcript(
      fullText: fields[0] as String,
      languageCode: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Transcript obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.fullText)
      ..writeByte(1)
      ..write(obj.languageCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AiResultAdapter extends TypeAdapter<AiResult> {
  @override
  final int typeId = 3;

  @override
  AiResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiResult(
      titleAr: fields[0] as String,
      titleEn: fields[1] as String,
      summaryAr: fields[2] as String,
      summaryEn: fields[3] as String,
      bulletPointsAr: (fields[4] as List).cast<String>(),
      bulletPointsEn: (fields[5] as List).cast<String>(),
      todosAr: (fields[6] as List).cast<String>(),
      todosEn: (fields[7] as List).cast<String>(),
      todosCompletedAr: (fields[8] as List?)?.cast<bool>(),
      todosCompletedEn: (fields[9] as List?)?.cast<bool>(),
    );
  }

  @override
  void write(BinaryWriter writer, AiResult obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.titleAr)
      ..writeByte(1)
      ..write(obj.titleEn)
      ..writeByte(2)
      ..write(obj.summaryAr)
      ..writeByte(3)
      ..write(obj.summaryEn)
      ..writeByte(4)
      ..write(obj.bulletPointsAr)
      ..writeByte(5)
      ..write(obj.bulletPointsEn)
      ..writeByte(6)
      ..write(obj.todosAr)
      ..writeByte(7)
      ..write(obj.todosEn)
      ..writeByte(8)
      ..write(obj.todosCompletedAr)
      ..writeByte(9)
      ..write(obj.todosCompletedEn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConversationAdapter extends TypeAdapter<Conversation> {
  @override
  final int typeId = 4;

  @override
  Conversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Conversation(
      id: fields[0] as String,
      type: fields[1] as ConversationType,
      title: fields[2] as String,
      subtitle: fields[3] as String?,
      primaryLanguage: fields[4] as String,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      audioSegments: (fields[7] as List).cast<AudioSegment>(),
      transcript: fields[8] as Transcript?,
      aiResult: fields[9] as AiResult?,
      isStarred: fields[10] as bool,
      folderId: fields[11] as String?,
      tags: (fields[12] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Conversation obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.subtitle)
      ..writeByte(4)
      ..write(obj.primaryLanguage)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.audioSegments)
      ..writeByte(8)
      ..write(obj.transcript)
      ..writeByte(9)
      ..write(obj.aiResult)
      ..writeByte(10)
      ..write(obj.isStarred)
      ..writeByte(11)
      ..write(obj.folderId)
      ..writeByte(12)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConversationTypeAdapter extends TypeAdapter<ConversationType> {
  @override
  final int typeId = 0;

  @override
  ConversationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConversationType.meeting;
      case 1:
        return ConversationType.memo;
      default:
        return ConversationType.meeting;
    }
  }

  @override
  void write(BinaryWriter writer, ConversationType obj) {
    switch (obj) {
      case ConversationType.meeting:
        writer.writeByte(0);
        break;
      case ConversationType.memo:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
