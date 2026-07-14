import 'message.dart';

class Conversation {
  final String conversationId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String model;
  final ConversationMetadata metadata;
  final List<Message> messages;

  Conversation({
    required this.conversationId,
    this.title = '新对话',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.model = 'deepseek-chat',
    ConversationMetadata? metadata,
    List<Message>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        metadata = metadata ?? ConversationMetadata(),
        messages = messages ?? [];

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: json['conversation_id'] ?? '',
      title: json['title'] ?? '新对话',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      model: json['model'] ?? 'deepseek-chat',
      metadata: json['metadata'] != null
          ? ConversationMetadata.fromJson(json['metadata'])
          : ConversationMetadata(),
      messages: json['messages'] != null
          ? (json['messages'] as List).map((m) => Message.fromJson(m)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'model': model,
        'metadata': metadata.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

class ConversationMetadata {
  final int messageCount;
  final int searchCount;
  final List<String> topics;
  final List<String> moodTrajectory;

  ConversationMetadata({
    this.messageCount = 0,
    this.searchCount = 0,
    this.topics = const [],
    this.moodTrajectory = const [],
  });

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) {
    return ConversationMetadata(
      messageCount: json['message_count'] ?? 0,
      searchCount: json['search_count'] ?? 0,
      topics: List<String>.from(json['topics'] ?? []),
      moodTrajectory: List<String>.from(json['mood_trajectory'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'message_count': messageCount,
        'search_count': searchCount,
        'topics': topics,
        'mood_trajectory': moodTrajectory,
      };
}
