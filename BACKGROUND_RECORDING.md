# Background Recording Implementation

This document describes the implementation of background recording capability for the Callout app, allowing audio recording to continue even when the screen is locked or the app is in the background.

## Overview

The implementation uses platform-specific approaches:
- **Android**: Foreground service with persistent notification
- **iOS**: Background audio mode
- **Both platforms**: Wake lock to prevent CPU sleep during recording

## Packages Added

1. **flutter_foreground_task (^8.14.0)** - Manages foreground service on Android and provides notification support
2. **wakelock_plus (^1.2.8)** - Prevents device from sleeping during recording on both platforms

## Android Implementation

### Permissions (AndroidManifest.xml)

Added the following permissions:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### Foreground Service Configuration

Registered the foreground service with microphone type:
```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="microphone"
    android:exported="false"
    android:stopWithTask="true" />
```

### Features
- Shows persistent notification while recording
- Notification displays "Recording in progress" with current status
- Updates to "Recording paused" when recording is paused
- Includes "Stop" button in notification for quick access
- Tapping notification brings user back to the app

## iOS Implementation

### Background Modes (Info.plist)

Added background audio capability:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

### Features
- Recording continues when app is in background
- Recording continues when screen is locked
- Audio session remains active in background mode

## Implementation Details

### BackgroundRecordingService

Created a new service (`lib/core/services/background_recording_service.dart`) that handles:

1. **Initialization** - Sets up foreground task configuration
2. **Service Management** - Starts/stops background recording capability
3. **Wake Lock** - Prevents CPU from sleeping during recording
4. **Notification Updates** - Updates Android notification with current status
5. **Permission Handling** - Requests notification permission on Android 13+

Key methods:
- `initialize()` - Initialize service (called once at app startup)
- `startService()` - Start background recording mode
- `stopService()` - Stop background recording mode
- `updateNotification()` - Update notification text (Android)
- `requestNotificationPermission()` - Request notification permission (Android 13+)

### AudioRecorderService Updates

Enhanced the existing audio recorder service to integrate background recording:

1. **Service Start** - Automatically starts background service when recording begins
2. **Service Stop** - Automatically stops background service when recording ends
3. **Notification Updates** - Updates notification when paused/resumed (Android)
4. **Cleanup** - Ensures background service is stopped on disposal

### Main App Initialization

Updated `main.dart` to initialize the background recording service at app startup:
```dart
await BackgroundRecordingService.initialize();
```

## User Experience

### Android
1. User starts recording
2. Persistent notification appears in status bar
3. User can lock screen or switch to other apps
4. Recording continues in background
5. Notification shows current status and duration
6. User can tap notification to return to app
7. User can tap "Stop" in notification or return to app to stop

### iOS
1. User starts recording
2. Audio session is configured for background
3. User can lock screen or switch to other apps
4. Recording continues in background
5. User returns to app to stop recording

## Testing Checklist

### Android Testing
- [ ] Recording continues when screen is locked
- [ ] Recording continues when app is in background
- [ ] Recording continues when switching to other apps
- [ ] Notification appears when recording starts
- [ ] Notification updates when paused/resumed
- [ ] Notification "Stop" button works
- [ ] Tapping notification returns to app
- [ ] Recording stops properly
- [ ] Background service stops when recording ends
- [ ] Works on Android 13+ with notification permission

### iOS Testing
- [ ] Recording continues when screen is locked
- [ ] Recording continues when app is in background
- [ ] Recording continues when switching to other apps
- [ ] Audio quality is maintained in background
- [ ] Recording stops properly
- [ ] No crashes when returning from background

## Important Notes

1. **Notification Permission (Android 13+)**: On Android 13 and above, users must grant notification permission for the foreground service to work properly.

2. **Battery Optimization**: Users should be aware that background recording will consume more battery. The wake lock ensures recording isn't interrupted, but may impact battery life.

3. **Recording Quality**: The audio recording quality remains the same in background mode (44.1kHz sample rate, 128kbps bitrate, AAC-LC encoding).

4. **Service Lifecycle**: The foreground service is tied to the recording lifecycle - it starts when recording begins and stops when recording ends.

5. **iOS Background Limits**: While iOS allows background audio recording, the system may terminate the app if it uses excessive resources. The implementation is optimized to minimize resource usage.

## Troubleshooting

### Android: Notification Not Showing
- Check notification permission is granted (Android 13+)
- Verify foreground service permissions in manifest
- Check notification channel settings

### Android: Recording Stops in Background
- Verify wake lock permission
- Check battery optimization settings for the app
- Ensure foreground service type is set to "microphone"

### iOS: Recording Stops in Background
- Verify UIBackgroundModes includes "audio"
- Check microphone permission is granted
- Ensure audio session is properly configured

### Both Platforms: High Battery Drain
- This is expected behavior due to wake lock
- Recording in background requires keeping CPU active
- Consider informing users about battery impact

## Next Steps

1. Run `flutter pub get` to install new packages
2. For iOS, run `pod install` in the ios directory
3. Test on physical devices (background features don't work reliably on simulators)
4. Consider adding user notification about battery usage
5. Consider adding a recording duration limit to prevent excessive battery drain

## Code Generation

After adding this feature, remember to regenerate providers:
```bash
dart run build_runner build --delete-conflicting-outputs
```
