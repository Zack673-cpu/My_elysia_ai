import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  Conversation? _currentConversation;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamingContent = '';
  String? _error;
  List<Conversation> _conversations = [];

  Conversation? get currentConversation => _currentConversation;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String get streamingContent => _streamingContent;
  String? get error => _error;
  List<Conversation> get conversations => _conversations;

  /// 创建新对话
  Future<void> createNewConversation() async {
    try {
      _error = null;
      _currentConversation = await _chatService.createConversation();
      _messages = [];
      _streamingContent = '';
      notifyListeners();
    } catch (e) {
      _error = '创建对话失败: $e';
      notifyListeners();
    }
  }

  /// 加载对话列表
  Future<void> loadConversations() async {
    try {
      _conversations = await _chatService.getConversations();
      notifyListeners();
    } catch (e) {
      _error = '加载对话列表失败: $e';
      notifyListeners();
    }
  }

  /// 切换到指定对话
  Future<void> switchConversation(String conversationId) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      _currentConversation = await _chatService.getConversation(conversationId);
      _messages = _currentConversation!.messages
          .where((m) => m.role != 'system_context')
          .toList();
      _streamingContent = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = '加载对话失败: $e';
      notifyListeners();
    }
  }

  /// 删除对话
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _chatService.deleteConversation(conversationId);
      if (_currentConversation?.conversationId == conversationId) {
        _currentConversation = null;
        _messages = [];
      }
      await loadConversations();
    } catch (e) {
      _error = '删除对话失败: $e';
      notifyListeners();
    }
  }

  /// 发送消息（流式）
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // 如果没有当前对话，先创建一个
    if (_currentConversation == null) {
      await createNewConversation();
    }

    // 添加用户消息到列表
    final userMessage = Message(role: 'user', content: content);
    _messages.add(userMessage);
    _isLoading = true;
    _isStreaming = true;
    _streamingContent = '';
    _error = null;
    notifyListeners();

    try {
      await for (final chunk
          in _chatService.sendMessageStream(_currentConversation!.conversationId, content)) {
        if (chunk.done) {
          break;
        }
        _streamingContent += chunk.content;
        notifyListeners();
      }

      // 流结束，将完整回复添加到消息列表
      final assistantMessage = Message(
        role: 'assistant',
        content: _streamingContent,
      );
      _messages.add(assistantMessage);
      _streamingContent = '';
      _isStreaming = false;
      _isLoading = false;
      notifyListeners();

      // 刷新对话列表
      await loadConversations();
    } catch (e) {
      _isStreaming = false;
      _isLoading = false;
      _error = '发送消息失败: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
