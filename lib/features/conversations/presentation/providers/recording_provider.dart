import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:record/record.dart';
import '../../../../core/services/audio_recorder_service.dart';

part 'recording_provider.g.dart';

@riverpod
class RecordingController extends _$RecordingController {
  String? _currentPath;

  @override
  RecordState build() {
    return RecordState.stop;
  }

  String? get currentPath => _currentPath;

  Future<void> startRecording() async {
    final service = ref.read(audioRecorderServiceProvider);
    _currentPath = await service.startRecording();
    state = RecordState.record;
  }

  Future<String?> stopRecording() async {
    final service = ref.read(audioRecorderServiceProvider);
    final path = await service.stopRecording();
    state = RecordState.stop;
    final returnPath = _currentPath ?? path;
    _currentPath = null;
    return returnPath;
  }

  Future<void> pauseRecording() async {
    final service = ref.read(audioRecorderServiceProvider);
    await service.pauseRecording();
    state = RecordState.pause;
  }

  Future<void> resumeRecording() async {
    final service = ref.read(audioRecorderServiceProvider);
    await service.resumeRecording();
    state = RecordState.record;
  }
}

@riverpod
class CurrentRecordingPath extends _$CurrentRecordingPath {
  @override
  String? build() => null;

  void setPath(String path) {
    state = path;
  }

  void clear() {
    state = null;
  }
}

@riverpod
Stream<Amplitude> recordingAmplitude(RecordingAmplitudeRef ref) {
  final service = ref.watch(audioRecorderServiceProvider);
  return service.onAmplitudeChanged;
}

@riverpod
class RecordingDuration extends _$RecordingDuration {
  Timer? _timer;
  int _durationSeconds = 0;

  @override
  int build() {
    final recordState = ref.watch(recordingControllerProvider);

    if (recordState == RecordState.record) {
      _startTimer();
    } else if (recordState == RecordState.stop) {
      _stopTimer();
      _durationSeconds = 0;
    } else if (recordState == RecordState.pause) {
      _stopTimer();
    }

    ref.onDispose(() {
      _stopTimer();
    });

    return _durationSeconds;
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationSeconds++;
      state = _durationSeconds;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
