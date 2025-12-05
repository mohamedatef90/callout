import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/storage_service.dart';
import '../models/folder_model.dart';

part 'folder_repository.g.dart';

class FolderRepository {
  final Box<Folder> _box;

  FolderRepository(this._box);

  List<Folder> getAllFolders() {
    return _box.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Folder? getFolder(String id) {
    return _box.get(id);
  }

  Future<void> saveFolder(Folder folder) async {
    await _box.put(folder.id, folder);
  }

  Future<void> deleteFolder(String id) async {
    await _box.delete(id);
  }
}

@Riverpod(keepAlive: true)
FolderRepository folderRepository(FolderRepositoryRef ref) {
  final box = ref.watch(folderBoxProvider);
  return FolderRepository(box);
}
