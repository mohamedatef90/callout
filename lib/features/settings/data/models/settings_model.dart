import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 7)
class AppSettings {
  @HiveField(0)
  final bool deleteAudioAfterTranscription;

  @HiveField(1)
  final bool enableNotifications;

  @HiveField(2)
  final String defaultLanguage;

  @HiveField(3)
  final String ttsProvider; // 'device', 'openai', 'googleCloud'

  AppSettings({
    this.deleteAudioAfterTranscription = false,
    this.enableNotifications = true,
    this.defaultLanguage = 'en',
    this.ttsProvider = 'device',
  });

  AppSettings copyWith({
    bool? deleteAudioAfterTranscription,
    bool? enableNotifications,
    String? defaultLanguage,
    String? ttsProvider,
  }) {
    return AppSettings(
      deleteAudioAfterTranscription:
          deleteAudioAfterTranscription ?? this.deleteAudioAfterTranscription,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      ttsProvider: ttsProvider ?? this.ttsProvider,
    );
  }
}
