import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _settingsKey = 'app_settings';
  static const String _currentConversationKey = 'current_conversation_id';

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_settingsKey);
    if (data != null) {
      return AppSettings.fromJson(jsonDecode(data));
    }
    return const AppSettings();
  }

  Future<void> saveCurrentConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentConversationKey, id);
  }

  Future<String?> loadCurrentConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentConversationKey);
  }

  Future<void> clearCurrentConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentConversationKey);
  }
}
