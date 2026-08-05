import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../services/autostart_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();
  final AutostartService _autostart = AutostartService();

  AppSettings _settings = const AppSettings();
  bool _isConnected = false;

  AppSettings get settings => _settings;
  bool get isConnected => _isConnected;

  /// 初始化：加载保存的设置并检查连接
  Future<void> init() async {
    _settings = await _storage.loadSettings();
    ApiConfig.setBaseUrl(_settings.baseUrl);
    await _checkConnectionWithRetry();
    await _syncBackendSettings();
    notifyListeners();
  }

  /// 开机自启时后端脚本需要几秒才就绪，未连上时等待重试（最多约 30 秒）
  Future<void> _checkConnectionWithRetry() async {
    _isConnected = await _api.checkHealth();
    notifyListeners();
    var attempts = 0;
    while (!_isConnected && attempts < 15) {
      await Future.delayed(const Duration(seconds: 2));
      attempts++;
      _isConnected = await _api.checkHealth();
      notifyListeners();
    }
  }

  /// 检查后端连接
  Future<void> checkConnection() async {
    _isConnected = await _api.checkHealth();
    notifyListeners();
  }

  /// 从后端同步问答领域、新闻范围（后端数据库才是权威来源）
  Future<void> _syncBackendSettings() async {
    if (!_isConnected) return;
    try {
      final data = await _api.getSettings();
      _settings = _settings.copyWith(
        quizTopic: data['quiz_topic'] ?? _settings.quizTopic,
        newsScope: data['news_scope'] ?? _settings.newsScope,
      );
      await _storage.saveSettings(_settings);
    } catch (_) {}
  }

  /// 更新模型
  Future<void> setModel(String model) async {
    _settings = _settings.copyWith(model: model);
    await _storage.saveSettings(_settings);
    try {
      await _api.updateSettings(model: model);
    } catch (_) {}
    notifyListeners();
  }

  /// 更新后端地址
  Future<void> setBaseUrl(String url) async {
    _settings = _settings.copyWith(baseUrl: url);
    ApiConfig.setBaseUrl(url);
    await _storage.saveSettings(_settings);
    await checkConnection();
    notifyListeners();
  }

  /// 切换深色模式
  Future<void> toggleDarkMode(bool isDark) async {
    _settings = _settings.copyWith(isDarkMode: isDark);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 更新每日问答领域
  Future<void> setQuizTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return;
    _settings = _settings.copyWith(quizTopic: trimmed);
    await _storage.saveSettings(_settings);
    try {
      await _api.updateSettings(quizTopic: trimmed);
    } catch (_) {}
    notifyListeners();
  }

  /// 更新每日新闻范围
  Future<void> setNewsScope(String scope) async {
    final trimmed = scope.trim();
    if (trimmed.isEmpty) return;
    _settings = _settings.copyWith(newsScope: trimmed);
    await _storage.saveSettings(_settings);
    try {
      await _api.updateSettings(newsScope: trimmed);
    } catch (_) {}
    notifyListeners();
  }

  /// 更新后端目录（开机自启脚本用）
  Future<void> setBackendDir(String dir) async {
    final trimmed = dir.trim();
    if (trimmed.isEmpty) return;
    _settings = _settings.copyWith(backendDir: trimmed);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  /// 切换开机自启动。返回 null 成功，否则返回失败原因。
  Future<String?> setAutoStart(bool enabled) async {
    if (enabled) {
      final error = await _autostart.enable(
        backendDir: _settings.backendDir,
        baseUrl: _settings.baseUrl,
      );
      if (error != null) return error;
    } else {
      await _autostart.disable();
    }
    _settings = _settings.copyWith(autoStart: enabled);
    await _storage.saveSettings(_settings);
    notifyListeners();
    return null;
  }
}
