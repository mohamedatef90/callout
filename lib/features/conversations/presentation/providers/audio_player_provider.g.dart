// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioPositionHash() => r'db4269294ba7578df92c72081d296e68e2761ac8';

/// See also [audioPosition].
@ProviderFor(audioPosition)
final audioPositionProvider = AutoDisposeStreamProvider<Duration>.internal(
  audioPosition,
  name: r'audioPositionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioPositionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AudioPositionRef = AutoDisposeStreamProviderRef<Duration>;
String _$audioDurationHash() => r'79e070517672314f31ea71a418b366b08a2f04f0';

/// See also [audioDuration].
@ProviderFor(audioDuration)
final audioDurationProvider = AutoDisposeStreamProvider<Duration>.internal(
  audioDuration,
  name: r'audioDurationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioDurationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AudioDurationRef = AutoDisposeStreamProviderRef<Duration>;
String _$audioPlayerControllerHash() =>
    r'097020f660edd46a42d72be1d5ba69c723a11c5f';

/// See also [AudioPlayerController].
@ProviderFor(AudioPlayerController)
final audioPlayerControllerProvider =
    AutoDisposeNotifierProvider<AudioPlayerController, PlayerState>.internal(
  AudioPlayerController.new,
  name: r'audioPlayerControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioPlayerControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AudioPlayerController = AutoDisposeNotifier<PlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
