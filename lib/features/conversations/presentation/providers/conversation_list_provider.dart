import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/conversation_repository.dart';

part 'conversation_list_provider.g.dart';

@riverpod
class ConversationList extends _$ConversationList {
  @override
  List<Conversation> build() {
    final repository = ref.watch(conversationRepositoryProvider);
    return repository.getAllConversations();
  }

  Future<void> addConversation(Conversation conversation) async {
    final repository = ref.read(conversationRepositoryProvider);
    await repository.saveConversation(conversation);
    ref.invalidateSelf();
  }

  Future<void> deleteConversation(String id) async {
    final repository = ref.read(conversationRepositoryProvider);
    await repository.deleteConversation(id);
    ref.invalidateSelf();
  }
}
