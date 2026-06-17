class Message {
  final String role; // user, assistant, system_context
  final String content;
  final DateTime timestamp;
  final MessageMetadata metadata;

  Message({
    required this.role,
    required this.content,
    DateTime? timestamp,
    MessageMetadata? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? MessageMetadata();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'] != null
          ? MessageMetadata.fromJson(json['metadata'])
          : MessageMetadata(),
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata.toJson(),
      };

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystemContext => role == 'system_context';
}

class MessageMetadata {
  final String? modelUsed;
  final bool searchPerformed;
  final String? searchQuery;
  final List<Map<String, dynamic>>? searchResults;
  final int? tokensUsed;

  MessageMetadata({
    this.modelUsed,
    this.searchPerformed = false,
    this.searchQuery,
    this.searchResults,
    this.tokensUsed,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      modelUsed: json['model_used'],
      searchPerformed: json['search_performed'] ?? false,
      searchQuery: json['search_query'],
      searchResults: json['search_results'] != null
          ? List<Map<String, dynamic>>.from(json['search_results'])
          : null,
      tokensUsed: json['tokens_used'],
    );
  }

  Map<String, dynamic> toJson() => {
        'model_used': modelUsed,
        'search_performed': searchPerformed,
        'search_query': searchQuery,
        'search_results': searchResults,
        'tokens_used': tokensUsed,
      };
}
