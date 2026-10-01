import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_model.dart';
import 'voice_chat_provider.dart';
import 'auth_provider.dart';

class ConversationListNotifier extends AsyncNotifier<List<ConversationModel>> {
  @override
  Future<List<ConversationModel>> build() async {
    final user = ref.watch(authProvider).asData?.value;
    final repo = ref.read(voiceChatProvider.notifier).repository;
    return await repo.fetchConversations(userId: user?.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final user = ref.read(authProvider).asData?.value;
    final repo = ref.read(voiceChatProvider.notifier).repository;
    final list = await repo.fetchConversations(userId: user?.id);
    state = AsyncData(list);
  }

  void forceUpdate(List<ConversationModel> list) {
    state = AsyncData(List.from(list));
  }

  /// 로그아웃 시 상태를 빈 리스트로 초기화하고 로컬 캐시를 클리어합니다.
  void clear() {
    final repo = ref.read(voiceChatProvider.notifier).repository;
    repo.clearLocalCache();
    state = const AsyncData([]);
  }
}

final conversationListProvider = AsyncNotifierProvider<ConversationListNotifier, List<ConversationModel>>(() {
  return ConversationListNotifier();
});
