/// 每日问答状态（对应后端 GET /api/daily/today 的返回）
class DailyState {
  final String date;
  final bool isReview;
  final int cardId;
  final String question;
  final String topic;
  final int level;
  final bool answered;
  final bool resolved;
  final String? userAnswer;
  final String? feedback;
  final String? suggestion;
  final String? grade; // correct / wrong / partial
  final bool isMasteryExam;

  /// 需要用户弹窗决策的类型：new_question / review_partial / mastery_exam / null
  final String? decision;
  final int dueCount;

  DailyState({
    required this.date,
    required this.isReview,
    required this.cardId,
    required this.question,
    this.topic = '',
    this.level = 1,
    this.answered = false,
    this.resolved = false,
    this.userAnswer,
    this.feedback,
    this.suggestion,
    this.grade,
    this.isMasteryExam = false,
    this.decision,
    this.dueCount = 0,
  });

  factory DailyState.fromJson(Map<String, dynamic> json) {
    return DailyState(
      date: json['date'] ?? '',
      isReview: json['is_review'] ?? false,
      cardId: json['card_id'] ?? 0,
      question: json['question'] ?? '',
      topic: json['topic'] ?? '',
      level: json['level'] ?? 1,
      answered: json['answered'] ?? false,
      resolved: json['resolved'] ?? false,
      userAnswer: json['user_answer'],
      feedback: json['feedback'],
      suggestion: json['suggestion'],
      grade: json['grade'],
      isMasteryExam: json['is_mastery_exam'] ?? false,
      decision: json['decision'],
      dueCount: json['due_count'] ?? 0,
    );
  }

  /// 今日是否已完成（已作答且决策完成）
  bool get isDone => answered && resolved;
}

/// 每日新闻条目
class NewsItem {
  final int id;
  final String summary;
  final String url;
  final String sourceTitle;
  final DateTime fetchedAt;

  NewsItem({
    required this.id,
    required this.summary,
    required this.url,
    this.sourceTitle = '',
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] ?? 0,
      summary: json['summary'] ?? '',
      url: json['url'] ?? '',
      sourceTitle: json['source_title'] ?? '',
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'])
          : null,
    );
  }
}
