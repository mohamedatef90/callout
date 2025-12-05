import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/audio_player_service.dart';

part 'audio_player_provider.g.dart';

@riverpod
class AudioPlayerController extends _$AudioPlayerController {
  @override
  PlayerState build() {
    return PlayerState.stopped;
  }

  Future<void> play(String filePath) async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.play(filePath);
    state = PlayerState.playing;
  }

  Future<void> pause() async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.pause();
    state = PlayerState.paused;
  }

  Future<void> resume() async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.resume();
    state = PlayerState.playing;
  }

  Future<void> stop() async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.stop();
    state = PlayerState.stopped;
  }

  Future<void> seek(Duration position) async {
    final service = ref.read(audioPlayerServiceProvider);
    await service.seek(position);
  }
}

@riverpod
Stream<Duration> audioPosition(AudioPositionRef ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.onPositionChanged;
}

@riverpod
Stream<Duration> audioDuration(AudioDurationRef ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.onDurationChanged;
}
