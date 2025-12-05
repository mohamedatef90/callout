import 'package:hive/hive.dart';

part 'reminder_model.g.dart';

@HiveType(typeId: 8)
class Reminder {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime dateTime;

  @HiveField(4)
  final String? conversationId;

  @HiveField(5)
  final String? todoText;

  @HiveField(6)
  final bool isCompleted;

  @HiveField(7)
  final bool notificationScheduled;

  @HiveField(8)
  final String? calendarEventId;

  @HiveField(9)
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.conversationId,
    this.todoText,
    this.isCompleted = false,
    this.notificationScheduled = false,
    this.calendarEventId,
    required this.createdAt,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? conversationId,
    String? todoText,
    bool? isCompleted,
    bool? notificationScheduled,
    String? calendarEventId,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      conversationId: conversationId ?? this.conversationId,
      todoText: todoText ?? this.todoText,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationScheduled: notificationScheduled ?? this.notificationScheduled,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
