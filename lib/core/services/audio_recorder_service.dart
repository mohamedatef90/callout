import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'audio_recorder_service.g.dart';

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<bool> requestPermission() async {
    // On iOS/Android, hasPermission() will trigger the permission dialog if not yet granted
    final hasPermission = await _audioRecorder.hasPermission();
    return hasPermission;
  }

  Future<String> startRecording() async {
    // Request permission using the record package's built-in method
    final hasPermission = await requestPermission();

    if (!hasPermission) {
      throw Exception('Microphone permission not granted. Please enable it in Settings.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${const Uuid().v4()}.m4a';
    final path = '${dir.path}/$fileName';

    // Use appropriate encoder based on platform
    final config = RecordConfig(
      encoder: Platform.isIOS ? AudioEncoder.aacLc : AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 128000,
    );

    await _audioRecorder.start(config, path: path);
    return path;
  }

  Future<String?> stopRecording() async {
    return await _audioRecorder.stop();
  }

  Future<void> pauseRecording() async {
    await _audioRecorder.pause();
  }

  Future<void> resumeRecording() async {
    await _audioRecorder.resume();
  }

  Future<void> dispose() async {
    _audioRecorder.dispose();
  }

  Stream<RecordState> get onStateChanged => _audioRecorder.onStateChanged();

  // Stream for amplitude (waveform)
  Stream<Amplitude> get onAmplitudeChanged =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));
}

@Riverpod(keepAlive: true)
AudioRecorderService audioRecorderService(AudioRecorderServiceRef ref) {
  final service = AudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
}
