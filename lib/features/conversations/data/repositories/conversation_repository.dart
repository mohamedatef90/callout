import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/storage_service.dart';
import '../models/conversation_model.dart';

part 'conversation_repository.g.dart';

class ConversationRepository {
  final Box<Conversation> _box;

  ConversationRepository(this._box);

  List<Conversation> getAllConversations() {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Conversation? getConversation(String id) {
    return _box.get(id);
  }

  Future<void> saveConversation(Conversation conversation) async {
    await _box.put(conversation.id, conversation);
  }

  Future<void> deleteConversation(String id) async {
    await _box.delete(id);
  }
}

@Riverpod(keepAlive: true)
ConversationRepository conversationRepository(ConversationRepositoryRef ref) {
  final box = ref.watch(conversationBoxProvider);
  return ConversationRepository(box);
}
