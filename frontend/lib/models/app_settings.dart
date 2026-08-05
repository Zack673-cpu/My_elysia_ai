class AppSettings {
  final String model;     // deepseek model name
  final String baseUrl;   // backend URL
  final bool isDarkMode;
  final String quizTopic;   // 每日问答领域（后端持久化，前端留一份方便显示）
  final String newsScope;   // 每日新闻范围（后端持久化）
  final bool autoStart;     // 开机自启动（本机注册表）
  final String backendDir;  // 后端目录（注册开机自启用）

  const AppSettings({
    this.model = 'deepseek-chat',
    this.baseUrl = 'http://localhost:8000',
    this.isDarkMode = false,
    this.quizTopic = '前后端全栈',
    this.newsScope = 'AI',
    this.autoStart = false,
    this.backendDir = r'D:\My_Elysia_ai\backend',
  });

  AppSettings copyWith({
    String? model,
    String? baseUrl,
    bool? isDarkMode,
    String? quizTopic,
    String? newsScope,
    bool? autoStart,
    String? backendDir,
  }) {
    return AppSettings(
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      quizTopic: quizTopic ?? this.quizTopic,
      newsScope: newsScope ?? this.newsScope,
      autoStart: autoStart ?? this.autoStart,
      backendDir: backendDir ?? this.backendDir,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      model: json['model'] ?? 'deepseek-chat',
      baseUrl: json['base_url'] ?? 'http://localhost:8000',
      isDarkMode: json['is_dark_mode'] ?? false,
      quizTopic: json['quiz_topic'] ?? '前后端全栈',
      newsScope: json['news_scope'] ?? 'AI',
      autoStart: json['auto_start'] ?? false,
      backendDir: json['backend_dir'] ?? r'D:\My_Elysia_ai\backend',
    );
  }

  Map<String, dynamic> toJson() => {
        'model': model,
        'base_url': baseUrl,
        'is_dark_mode': isDarkMode,
        'quiz_topic': quizTopic,
        'news_scope': newsScope,
        'auto_start': autoStart,
        'backend_dir': backendDir,
      };
}
