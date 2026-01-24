import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service to manage background recording capabilities
/// Handles foreground service (Android) and background audio session (iOS)
class BackgroundRecordingService {
  static bool _isInitialized = false;
  static bool _isRunning = false;

  /// Initialize the foreground task service (Android only)
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'callout_recording_channel',
          channelName: 'Recording Service',
          channelDescription:
              'This notification appears when recording audio in the background.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
    }

    _isInitialized = true;
  }

  /// Start background recording service
  static Future<bool> startService() async {
    if (_isRunning) return true;

    try {
      // Enable wakelock to prevent CPU from sleeping during recording
      await WakelockPlus.enable();

      if (Platform.isAndroid) {
        // Start the foreground service for Android
        final result = await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Recording in progress',
          notificationText: 'Tap to return to the app',
          notificationButtons: [
            const NotificationButton(
              id: 'stop_recording',
              text: 'Stop',
            ),
          ],
          callback: backgroundServiceCallback,
        );

        if (result is ServiceRequestFailure) {
          await WakelockPlus.disable();
          return false;
        }
      }

      _isRunning = true;
      return true;
    } catch (e) {
      await WakelockPlus.disable();
      return false;
    }
  }

  /// Update the notification (Android only)
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (Platform.isAndroid && _isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  /// Stop background recording service
  static Future<void> stopService() async {
    if (!_isRunning) return;

    try {
      // Disable wakelock
      await WakelockPlus.disable();

      if (Platform.isAndroid) {
        // Stop the foreground service
        await FlutterForegroundTask.stopService();
      }

      _isRunning = false;
    } catch (e) {
      // Ensure wakelock is disabled even if service stop fails
      await WakelockPlus.disable();
      _isRunning = false;
    }
  }

  /// Check if the service is currently running
  static bool get isRunning => _isRunning;

  /// Request notification permission (Android 13+)
  static Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final NotificationPermission status =
          await FlutterForegroundTask.checkNotificationPermission();

      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
  }
}

/// Background service callback (required for flutter_foreground_task)
/// This runs in a separate isolate on Android
@pragma('vm:entry-point')
void backgroundServiceCallback() {
  // This callback is required but we don't need to do anything here
  // The actual recording is handled by the record package in the main isolate
  FlutterForegroundTask.setTaskHandler(BackgroundTaskHandler());
}

/// Task handler for the background service
class BackgroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Periodic event - not used for recording
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Service destroyed
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press
    if (id == 'stop_recording') {
      // The actual stop will be handled by the UI
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Handle notification tap - bring app to foreground
    FlutterForegroundTask.launchApp('/recording');
  }
}
