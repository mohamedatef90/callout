import 'package:hive_flutter/hive_flutter.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/conversations/data/models/conversation_model.dart';
import '../../features/conversations/data/models/folder_model.dart';
import '../../features/settings/data/models/settings_model.dart';
import '../../features/reminders/data/models/reminder_model.dart';

part 'storage_service.g.dart';

class StorageService {
  static const String conversationBoxName = 'conversations';
  static const String folderBoxName = 'folders';
  static const String settingsBoxName = 'settings';
  static const String reminderBoxName = 'reminders';

  Future<void> init() async {
    await Hive.initFlutter();

    _registerAdapters();

    await Hive.openBox<Conversation>(conversationBoxName);
    await Hive.openBox<Folder>(folderBoxName);
    await Hive.openBox<AppSettings>(settingsBoxName);
    await Hive.openBox<Reminder>(reminderBoxName);
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ConversationTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AudioSegmentAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TranscriptAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AiResultAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ConversationAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(FolderAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(ReminderAdapter());
    }
  }

  Future<void> clearAndReinit() async {
    await Hive.initFlutter();
    _registerAdapters();

    // Delete corrupted boxes
    await Hive.deleteBoxFromDisk(conversationBoxName);
    await Hive.deleteBoxFromDisk(folderBoxName);
    await Hive.deleteBoxFromDisk(settingsBoxName);
    await Hive.deleteBoxFromDisk(reminderBoxName);

    // Reopen fresh boxes
    await Hive.openBox<Conversation>(conversationBoxName);
    await Hive.openBox<Folder>(folderBoxName);
    await Hive.openBox<AppSettings>(settingsBoxName);
    await Hive.openBox<Reminder>(reminderBoxName);
  }

  Box<Conversation> get conversationBox =>
      Hive.box<Conversation>(conversationBoxName);

  Box<Folder> get folderBox => Hive.box<Folder>(folderBoxName);
}

@Riverpod(keepAlive: true)
StorageService storageService(StorageServiceRef ref) {
  return StorageService();
}

@Riverpod(keepAlive: true)
Box<Conversation> conversationBox(ConversationBoxRef ref) {
  return ref.watch(storageServiceProvider).conversationBox;
}

@Riverpod(keepAlive: true)
Box<Folder> folderBox(FolderBoxRef ref) {
  return ref.watch(storageServiceProvider).folderBox;
}
