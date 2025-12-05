import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../features/reminders/data/models/reminder_model.dart';
import '../../features/reminders/data/repositories/reminder_repository.dart';
import 'notification_service.dart';
import 'calendar_service.dart';

part 'reminder_service.g.dart';

class ReminderService {
  final ReminderRepository _repository;
  final NotificationService _notificationService;
  final CalendarService _calendarService;
  final _uuid = const Uuid();

  ReminderService({
    required ReminderRepository repository,
    required NotificationService notificationService,
    required CalendarService calendarService,
  })  : _repository = repository,
        _notificationService = notificationService,
        _calendarService = calendarService;

  Future<void> init() async {
    await _repository.init();
    await _notificationService.init();
    debugPrint('ReminderService: Initialized');
  }

  Future<List<Reminder>> getAllReminders() => _repository.getAll();

  Future<List<Reminder>> getUpcomingReminders() => _repository.getUpcoming();

  Future<List<Reminder>> getRemindersByConversation(String conversationId) =>
      _repository.getByConversation(conversationId);

  Future<Reminder> createReminder({
    required String title,
    String? description,
    required DateTime dateTime,
    String? conversationId,
    String? todoText,
    bool addToCalendar = false,
    bool scheduleNotification = true,
  }) async {
    final reminder = Reminder(
      id: _uuid.v4(),
      title: title,
      description: description,
      dateTime: dateTime,
      conversationId: conversationId,
      todoText: todoText,
      createdAt: DateTime.now(),
    );

    await _repository.save(reminder);

    // Schedule notification
    if (scheduleNotification && dateTime.isAfter(DateTime.now())) {
      await _scheduleNotification(reminder);
    }

    // Add to calendar
    if (addToCalendar) {
      await _addToCalendar(reminder);
    }

    debugPrint('ReminderService: Created reminder ${reminder.id}');
    return reminder;
  }

  Future<void> updateReminder(Reminder reminder) async {
    final oldReminder = await _repository.getById(reminder.id);

    // Cancel old notification if time changed
    if (oldReminder != null && oldReminder.dateTime != reminder.dateTime) {
      await _cancelNotification(reminder.id);
      if (reminder.dateTime.isAfter(DateTime.now())) {
        await _scheduleNotification(reminder);
      }
    }

    await _repository.save(reminder);
    debugPrint('ReminderService: Updated reminder ${reminder.id}');
  }

  Future<void> deleteReminder(String id) async {
    final reminder = await _repository.getById(id);
    if (reminder != null) {
      // Cancel notification
      await _cancelNotification(id);

      // Delete calendar event if exists
      if (reminder.calendarEventId != null) {
        final calendarId = await _calendarService.getDefaultCalendarId();
        if (calendarId != null) {
          await _calendarService.deleteEvent(
            calendarId: calendarId,
            eventId: reminder.calendarEventId!,
          );
        }
      }
    }

    await _repository.delete(id);
    debugPrint('ReminderService: Deleted reminder $id');
  }

  Future<void> markCompleted(String id, bool completed) async {
    await _repository.markCompleted(id, completed);
    if (completed) {
      await _cancelNotification(id);
    }
    debugPrint('ReminderService: Marked reminder $id as ${completed ? 'completed' : 'pending'}');
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    try {
      final hasPermission = await _notificationService.requestPermissions();
      if (!hasPermission) {
        debugPrint('ReminderService: No notification permission');
        return;
      }

      await _notificationService.scheduleReminder(
        id: _notificationService.generateNotificationId(reminder.id),
        title: 'Reminder: ${reminder.title}',
        body: reminder.description ?? reminder.todoText ?? 'You have a reminder',
        scheduledTime: reminder.dateTime,
        payload: reminder.id,
      );

      await _repository.updateNotificationStatus(reminder.id, true);
      debugPrint('ReminderService: Scheduled notification for ${reminder.dateTime}');
    } catch (e) {
      debugPrint('ReminderService: Failed to schedule notification: $e');
    }
  }

  Future<void> _cancelNotification(String reminderId) async {
    try {
      await _notificationService.cancelReminder(
        _notificationService.generateNotificationId(reminderId),
      );
      await _repository.updateNotificationStatus(reminderId, false);
      debugPrint('ReminderService: Cancelled notification for $reminderId');
    } catch (e) {
      debugPrint('ReminderService: Failed to cancel notification: $e');
    }
  }

  Future<void> _addToCalendar(Reminder reminder) async {
    try {
      final calendarId = await _calendarService.getDefaultCalendarId();
      if (calendarId == null) {
        debugPrint('ReminderService: No calendar available');
        return;
      }

      final eventId = await _calendarService.createEvent(
        calendarId: calendarId,
        title: reminder.title,
        description: reminder.description ?? reminder.todoText,
        startTime: reminder.dateTime,
        endTime: reminder.dateTime.add(const Duration(minutes: 30)),
      );

      if (eventId != null) {
        await _repository.updateCalendarEventId(reminder.id, eventId);
        debugPrint('ReminderService: Added to calendar with event ID: $eventId');
      }
    } catch (e) {
      debugPrint('ReminderService: Failed to add to calendar: $e');
    }
  }

  Future<bool> addExistingReminderToCalendar(String reminderId) async {
    try {
      final reminder = await _repository.getById(reminderId);
      if (reminder == null) return false;

      await _addToCalendar(reminder);
      return true;
    } catch (e) {
      debugPrint('ReminderService: Failed to add existing reminder to calendar: $e');
      return false;
    }
  }

  Future<void> rescheduleAllNotifications() async {
    final reminders = await _repository.getUpcoming();
    for (final reminder in reminders) {
      if (!reminder.isCompleted && reminder.dateTime.isAfter(DateTime.now())) {
        await _scheduleNotification(reminder);
      }
    }
    debugPrint('ReminderService: Rescheduled ${reminders.length} notifications');
  }
}

@Riverpod(keepAlive: true)
ReminderService reminderService(ReminderServiceRef ref) {
  return ReminderService(
    repository: ref.read(reminderRepositoryProvider),
    notificationService: ref.read(notificationServiceProvider),
    calendarService: ref.read(calendarServiceProvider),
  );
}
