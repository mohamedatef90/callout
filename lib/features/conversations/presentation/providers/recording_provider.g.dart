// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordingAmplitudeHash() =>
    r'548ddc1aab7c5fa37963f54f11d8bdd350a65ea0';

/// See also [recordingAmplitude].
@ProviderFor(recordingAmplitude)
final recordingAmplitudeProvider =
    AutoDisposeStreamProvider<Amplitude>.internal(
  recordingAmplitude,
  name: r'recordingAmplitudeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recordingAmplitudeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecordingAmplitudeRef = AutoDisposeStreamProviderRef<Amplitude>;
String _$recordingControllerHash() =>
    r'ed9ea17de969a558bbe682308d67ae579ae534d3';

/// See also [RecordingController].
@ProviderFor(RecordingController)
final recordingControllerProvider =
    AutoDisposeNotifierProvider<RecordingController, RecordState>.internal(
  RecordingController.new,
  name: r'recordingControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recordingControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecordingController = AutoDisposeNotifier<RecordState>;
String _$currentRecordingPathHash() =>
    r'db09a0284239fcf98fc6d2584a255f4fee3eaca9';

/// See also [CurrentRecordingPath].
@ProviderFor(CurrentRecordingPath)
final currentRecordingPathProvider =
    AutoDisposeNotifierProvider<CurrentRecordingPath, String?>.internal(
  CurrentRecordingPath.new,
  name: r'currentRecordingPathProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentRecordingPathHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentRecordingPath = AutoDisposeNotifier<String?>;
String _$recordingDurationHash() => r'8bd534aae55d0b4d41735139ab59cee3c826cfcf';

/// See also [RecordingDuration].
@ProviderFor(RecordingDuration)
final recordingDurationProvider =
    AutoDisposeNotifierProvider<RecordingDuration, int>.internal(
  RecordingDuration.new,
  name: r'recordingDurationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recordingDurationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RecordingDuration = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
