import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_service.g.dart';

class CalendarService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  bool _hasPermissions = false;

  Future<bool> requestPermissions() async {
    final permissionsGranted = await _calendarPlugin.requestPermissions();
    _hasPermissions = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
    debugPrint('CalendarService: Permissions granted: $_hasPermissions');
    return _hasPermissions;
  }

  Future<bool> hasPermissions() async {
    final result = await _calendarPlugin.hasPermissions();
    _hasPermissions = result.isSuccess && (result.data ?? false);
    return _hasPermissions;
  }

  Future<List<Calendar>> getCalendars() async {
    if (!_hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) return [];
    }

    final result = await _calendarPlugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      return result.data!;
    }
    return [];
  }

  Future<String?> createEvent({
    required String calendarId,
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    bool allDay = false,
  }) async {
    if (!_hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) {
        debugPrint('CalendarService: No permissions to create event');
        return null;
      }
    }

    final event = Event(
      calendarId,
      title: title,
      description: description,
      start: TZDateTime.from(startTime, local),
      end: TZDateTime.from(endTime ?? startTime.add(const Duration(hours: 1)), local),
      allDay: allDay,
    );

    final result = await _calendarPlugin.createOrUpdateEvent(event);
    if (result?.isSuccess == true && result?.data != null) {
      debugPrint('CalendarService: Created event with ID: ${result!.data}');
      return result.data;
    }

    debugPrint('CalendarService: Failed to create event');
    return null;
  }

  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    if (!_hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) return false;
    }

    final result = await _calendarPlugin.deleteEvent(calendarId, eventId);
    final success = result.isSuccess && (result.data ?? false);
    debugPrint('CalendarService: Delete event $eventId: $success');
    return success;
  }

  Future<Event?> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    if (!_hasPermissions) {
      final granted = await requestPermissions();
      if (!granted) return null;
    }

    final now = DateTime.now();
    final result = await _calendarPlugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now.add(const Duration(days: 365)),
      ),
    );

    if (result.isSuccess && result.data != null) {
      try {
        return result.data!.firstWhere((e) => e.eventId == eventId);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<String?> getDefaultCalendarId() async {
    final calendars = await getCalendars();
    if (calendars.isEmpty) return null;

    // Try to find a default calendar (usually the first one or one marked as default)
    final defaultCalendar = calendars.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => calendars.first,
    );
    return defaultCalendar.id;
  }
}

@Riverpod(keepAlive: true)
CalendarService calendarService(CalendarServiceRef ref) {
  return CalendarService();
}
