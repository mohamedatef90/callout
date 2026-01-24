import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_recording_service.dart';
import 'core/theme/app_theme.dart';

import 'features/conversations/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize background recording service
  await BackgroundRecordingService.initialize();

  final container = ProviderContainer();

  try {
    await container.read(storageServiceProvider).init();
  } catch (e) {
    // If there's an error with Hive, clear the boxes and try again
    debugPrint('Error initializing storage: $e');
    await container.read(storageServiceProvider).clearAndReinit();
  }

  // Initialize notification service
  try {
    await container.read(notificationServiceProvider).init();
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisper',
      debugShowCheckedModeBanner: false,
      theme: WhisperTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
