import '../models/conversation.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api = ApiService();

  Future<Conversation> createConversation({String? title}) async {
    return _api.createConversation(title: title);
  }

  Future<List<Conversation>> getConversations() async {
    return _api.getConversations();
  }

  Future<Conversation> getConversation(String id) async {
    return _api.getConversation(id);
  }

  Future<void> deleteConversation(String id) async {
    return _api.deleteConversation(id);
  }

  /// 发送消息（非流式）
  Future<ChatResult> sendMessage(String conversationId, String message) async {
    return _api.sendMessage(conversationId, message);
  }

  /// 发送消息（流式）
  Stream<StreamChunk> sendMessageStream(
      String conversationId, String message) {
    return _api.sendMessageStream(conversationId, message);
  }

  Future<bool> checkHealth() => _api.checkHealth();

  void dispose() => _api.dispose();
}
