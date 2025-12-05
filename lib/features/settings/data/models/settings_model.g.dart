// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 7;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      deleteAudioAfterTranscription: fields[0] as bool? ?? false,
      enableNotifications: fields[1] as bool? ?? true,
      defaultLanguage: fields[2] as String? ?? 'en',
      ttsProvider: fields[3] as String? ?? 'device',
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.deleteAudioAfterTranscription)
      ..writeByte(1)
      ..write(obj.enableNotifications)
      ..writeByte(2)
      ..write(obj.defaultLanguage)
      ..writeByte(3)
      ..write(obj.ttsProvider);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
