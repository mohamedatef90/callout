import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/folder_model.dart';
import '../../data/repositories/folder_repository.dart';

part 'folder_provider.g.dart';

@riverpod
class FolderList extends _$FolderList {
  @override
  List<Folder> build() {
    final repository = ref.watch(folderRepositoryProvider);
    return repository.getAllFolders();
  }

  Future<void> addFolder(Folder folder) async {
    final repository = ref.read(folderRepositoryProvider);
    await repository.saveFolder(folder);
    ref.invalidateSelf();
  }

  Future<void> updateFolder(Folder folder) async {
    final repository = ref.read(folderRepositoryProvider);
    await repository.saveFolder(folder);
    ref.invalidateSelf();
  }

  Future<void> deleteFolder(String id) async {
    final repository = ref.read(folderRepositoryProvider);
    await repository.deleteFolder(id);
    ref.invalidateSelf();
  }
}

@riverpod
class SelectedFolder extends _$SelectedFolder {
  @override
  String? build() {
    return null;
  }

  void select(String? folderId) {
    state = folderId;
  }
}
