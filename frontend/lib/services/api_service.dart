import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/conversation.dart';
import '../models/daily.dart';
import '../models/message.dart';

class ApiService {
  final http.Client _client = http.Client();

  /// 健康检查
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(Uri.parse(ApiConfig.health));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 创建新对话
  Future<Conversation> createConversation({String? title}) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.conversations),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );
    if (response.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(response.body));
    }
    throw Exception('创建对话失败: ${response.statusCode}');
  }

  /// 获取所有对话
  Future<List<Conversation>> getConversations() async {
    final response = await _client.get(Uri.parse(ApiConfig.conversations));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((c) => Conversation.fromJson(c)).toList();
    }
    throw Exception('获取对话列表失败: ${response.statusCode}');
  }

  /// 获取单个对话详情
  Future<Conversation> getConversation(String id) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.conversationDetail(id)),
    );
    if (response.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(response.body));
    }
    throw Exception('获取对话失败: ${response.statusCode}');
  }

  /// 删除对话
  Future<void> deleteConversation(String id) async {
    final response = await _client.delete(
      Uri.parse(ApiConfig.conversationDetail(id)),
    );
    if (response.statusCode != 200) {
      throw Exception('删除对话失败: ${response.statusCode}');
    }
  }

  /// 发送消息（非流式）
  Future<ChatResult> sendMessage(String conversationId, String message) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.chatSend),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'conversation_id': conversationId,
        'message': message,
        'stream': false,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ChatResult(
        message: Message.fromJson(data['message']),
        searchPerformed: data['search_performed'] ?? false,
        searchResults: data['search_results'] != null
            ? List<Map<String, dynamic>>.from(data['search_results'])
            : null,
      );
    }
    throw Exception('发送消息失败: ${response.statusCode}');
  }

  /// 发送消息（流式 SSE）
  Stream<StreamChunk> sendMessageStream(
      String conversationId, String message) async* {
    final request = http.Request('POST', Uri.parse(ApiConfig.chatStream));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'conversation_id': conversationId,
      'message': message,
      'stream': true,
    });

    final response = await _client.send(request);
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6);
        try {
          final data = jsonDecode(dataStr);
          yield StreamChunk(
            content: data['content'] ?? '',
            done: data['done'] ?? false,
          );
        } catch (_) {
          // Skip malformed JSON
        }
      }
    }
  }

  /// 获取设置
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client.get(Uri.parse(ApiConfig.settings));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('获取设置失败: ${response.statusCode}');
  }

  /// 更新设置（模型 / 问答领域 / 新闻范围）
  Future<void> updateSettings({
    String? model,
    String? quizTopic,
    String? newsScope,
  }) async {
    final body = <String, dynamic>{};
    if (model != null) body['model'] = model;
    if (quizTopic != null) body['quiz_topic'] = quizTopic;
    if (newsScope != null) body['news_scope'] = newsScope;
    final response = await _client.put(
      Uri.parse(ApiConfig.settings),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('更新设置失败: ${response.statusCode}');
    }
  }

  /// 手动搜索
  Future<List<Map<String, dynamic>>> search(String query,
      {int maxResults = 5}) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.search),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'max_results': maxResults}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    throw Exception('搜索失败: ${response.statusCode}');
  }

  // ===== 每日问答 =====

  /// 获取今日每日问答题目；forceNew=true 为"再来一题"（消化积压）
  Future<DailyState> getDailyToday({bool forceNew = false}) async {
    final uri = Uri.parse(
      forceNew ? '${ApiConfig.dailyToday}?force_new=true' : ApiConfig.dailyToday,
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return DailyState.fromJson(jsonDecode(response.body));
    }
    throw Exception('获取每日问答失败: ${response.statusCode}');
  }

  /// 提交每日问答答案，返回 AI 评估后的状态
  Future<DailyState> submitDailyAnswer(String answer) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.dailyAnswer),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'answer': answer}),
    );
    if (response.statusCode == 200) {
      return DailyState.fromJson(jsonDecode(response.body));
    }
    throw Exception('提交答案失败: ${response.statusCode}');
  }

  /// 提交决策弹窗的按钮选择
  Future<DailyState> resolveDaily(String decision) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.dailyResolve),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'decision': decision}),
    );
    if (response.statusCode == 200) {
      return DailyState.fromJson(jsonDecode(response.body));
    }
    throw Exception('提交决策失败: ${response.statusCode}');
  }

  // ===== 每日新闻 =====

  Future<List<NewsItem>> getNews({int limit = 30}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.news}?limit=$limit'),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((n) => NewsItem.fromJson(n)).toList();
    }
    throw Exception('获取新闻失败: ${response.statusCode}');
  }

  // ===== 上下文压缩 =====

  Future<Map<String, dynamic>> compressConversation(String id) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.conversationCompress(id)),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('压缩失败: ${response.statusCode}');
  }

  void dispose() {
    _client.close();
  }
}

class ChatResult {
  final Message message;
  final bool searchPerformed;
  final List<Map<String, dynamic>>? searchResults;

  ChatResult({
    required this.message,
    this.searchPerformed = false,
    this.searchResults,
  });
}

class StreamChunk {
  final String content;
  final bool done;

  StreamChunk({this.content = '', this.done = false});
}
