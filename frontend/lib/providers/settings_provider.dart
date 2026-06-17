import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  AppSettings _settings = const AppSettings();
  bool _isConnected = false;

  AppSettings get settings => _settings;
  bool get isConnected => _isConnected;

  /// 初始化：加载保存的设置并检查连接
  Future<void> init() async {
    _settings = await _storage.loadSettings();
    ApiConfig.setBaseUrl(_settings.baseUrl);
    await checkConnection();
    notifyListeners();
  }

  /// 检查后端连接
  Future<void> checkConnection() async {
    _isConnected = await _api.checkHealth();
    notifyListeners();
  }

  /// 更新阶段
  Future<void> setStage(String stage) async {
    _settings = _settings.copyWith(stage: stage);
    await _storage.saveSettings(_settings);
    try {
      await _api.updateSettings(stage: stage);
    } catch (_) {}
    notifyListeners();
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
}
