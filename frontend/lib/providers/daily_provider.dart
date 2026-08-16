import 'package:flutter/foundation.dart';
import '../models/daily.dart';
import '../services/api_service.dart';

class DailyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  DailyState? _state;
  List<NewsItem> _news = [];
  bool _loadingQuestion = false;
  bool _submitting = false;
  String? _error;

  DailyState? get state => _state;
  bool get loadingQuestion => _loadingQuestion;
  bool get submitting => _submitting;
  String? get error => _error;

  /// 加载今日题目；forceNew=true 为"再来一题"
  Future<void> loadToday({bool forceNew = false}) async {
    _loadingQuestion = true;
    _error = null;
    notifyListeners();
    try {
      _state = await _api.getDailyToday(forceNew: forceNew);
    } catch (e) {
      _error = '获取每日问答失败: $e';
    }
    _loadingQuestion = false;
    notifyListeners();
  }

  /// 提交答案（回车或按钮触发）
  Future<void> submitAnswer(String answer) async {
    if (answer.trim().isEmpty || _submitting) return;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      _state = await _api.submitDailyAnswer(answer.trim());
    } catch (e) {
      _error = '提交答案失败: $e';
    }
    _submitting = false;
    notifyListeners();
  }

  /// 提交决策弹窗的按钮选择
  Future<void> resolve(String decision) async {
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      _state = await _api.resolveDaily(decision);
    } catch (e) {
      _error = '提交决策失败: $e';
    }
    _submitting = false;
    notifyListeners();
  }

  /// 加载最近一周的新闻库
  Future<void> loadNews() async {
    try {
      _news = await _api.getNews(limit: 30);
    } catch (_) {
      // 新闻加载失败不打断页面
    }
    notifyListeners();
  }

  /// 当天收集到的新闻（每日新闻区展示）
  List<NewsItem> get todayNews {
    final now = DateTime.now();
    return _news.where((n) {
      final t = n.fetchedAt.toLocal();
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).toList();
  }

  /// 最近一周收集的新闻（不含当天的，避免与每日新闻重复）
  List<NewsItem> get weekNews {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final todayIds = todayNews.map((n) => n.id).toSet();
    return _news.where((n) {
      final t = n.fetchedAt.toLocal();
      return t.isAfter(cutoff) && !todayIds.contains(n.id);
    }).toList();
  }
}
