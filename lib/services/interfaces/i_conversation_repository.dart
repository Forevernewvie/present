import '../../models/conversation_model.dart';
import '../conversation_repository.dart'; // For PendingSyncTurn

abstract class IConversationRepository {
  List<ConversationModel> get localConversations;
  List<PendingSyncTurn> get pendingSyncTurns;
  
  void clearLocalCache();
  
  Future<void> saveConversationTurn({
    required String? userId,
    required String userText,
    required DateTime userTime,
    required String aiText,
    required DateTime aiTime,
  });
  
  Future<int> syncPendingTurns();
  
  Future<List<ConversationModel>> fetchConversations({required String? userId});
}
