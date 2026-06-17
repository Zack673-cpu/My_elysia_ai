class ApiConfig {
  /// 后端 API 地址配置
  static String _baseUrl = 'http://localhost:8000';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  // API 端点
  static String get chatSend => '$_baseUrl/api/chat/send';
  static String get chatStream => '$_baseUrl/api/chat/stream';
  static String get conversations => '$_baseUrl/api/conversations';
  static String conversationDetail(String id) => '$_baseUrl/api/conversations/$id';
  static String get search => '$_baseUrl/api/search';
  static String get settings => '$_baseUrl/api/settings';
  static String get health => '$_baseUrl/api/health';
}
