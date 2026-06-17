class AppSettings {
  final String stage;     // demugo | cryene | elysia
  final String model;     // deepseek model name
  final String baseUrl;   // backend URL
  final bool isDarkMode;

  const AppSettings({
    this.stage = 'demugo',
    this.model = 'deepseek-chat',
    this.baseUrl = 'http://localhost:8000',
    this.isDarkMode = false,
  });

  AppSettings copyWith({
    String? stage,
    String? model,
    String? baseUrl,
    bool? isDarkMode,
  }) {
    return AppSettings(
      stage: stage ?? this.stage,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      stage: json['stage'] ?? 'demugo',
      model: json['model'] ?? 'deepseek-chat',
      baseUrl: json['base_url'] ?? 'http://localhost:8000',
      isDarkMode: json['is_dark_mode'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'model': model,
        'base_url': baseUrl,
        'is_dark_mode': isDarkMode,
      };
}
