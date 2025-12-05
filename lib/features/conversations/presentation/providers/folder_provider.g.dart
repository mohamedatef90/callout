// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$folderListHash() => r'38499ab34cf39db0af58d6b3ce926de6c08283f2';

/// See also [FolderList].
@ProviderFor(FolderList)
final folderListProvider =
    AutoDisposeNotifierProvider<FolderList, List<Folder>>.internal(
  FolderList.new,
  name: r'folderListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$folderListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FolderList = AutoDisposeNotifier<List<Folder>>;
String _$selectedFolderHash() => r'6ae356d2d40ad26cf336dbd588e794bdfcaa3f9c';

/// See also [SelectedFolder].
@ProviderFor(SelectedFolder)
final selectedFolderProvider =
    AutoDisposeNotifierProvider<SelectedFolder, String?>.internal(
  SelectedFolder.new,
  name: r'selectedFolderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedFolderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedFolder = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
