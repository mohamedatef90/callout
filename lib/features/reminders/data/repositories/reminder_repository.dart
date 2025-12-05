import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/reminder_model.dart';

part 'reminder_repository.g.dart';

class ReminderRepository {
  static const String _boxName = 'reminders';
  late Box<Reminder> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Reminder>(_boxName);
  }

  Box<Reminder> get box => _box;

  Future<List<Reminder>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reminder>> getUpcoming() async {
    final now = DateTime.now();
    return _box.values
        .where((r) => !r.isCompleted && r.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reminder>> getByConversation(String conversationId) async {
    return _box.values
        .where((r) => r.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<Reminder?> getById(String id) async {
    return _box.values.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Reminder not found'),
    );
  }

  Future<void> save(Reminder reminder) async {
    await _box.put(reminder.id, reminder);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> markCompleted(String id, bool completed) async {
    final reminder = await getById(id);
    if (reminder != null) {
      await save(reminder.copyWith(isCompleted: completed));
    }
  }

  Future<void> updateNotificationStatus(String id, bool scheduled) async {
    final reminder = await getById(id);
    if (reminder != null) {
      await save(reminder.copyWith(notificationScheduled: scheduled));
    }
  }

  Future<void> updateCalendarEventId(String id, String? eventId) async {
    final reminder = await getById(id);
    if (reminder != null) {
      await save(reminder.copyWith(calendarEventId: eventId));
    }
  }
}

@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(ReminderRepositoryRef ref) {
  return ReminderRepository();
}
