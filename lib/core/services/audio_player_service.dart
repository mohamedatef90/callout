import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_player_service.g.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged =>
      _audioPlayer.onPlayerStateChanged;

  Future<void> play(String filePath) async {
    await _audioPlayer.play(DeviceFileSource(filePath));
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<Duration?> getDuration(String filePath) async {
    await _audioPlayer.setSource(DeviceFileSource(filePath));
    return await _audioPlayer.getDuration();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(AudioPlayerServiceRef ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
}
