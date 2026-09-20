import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/daily_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsProvider _provider;
  late final TextEditingController _quizController;
  late final TextEditingController _newsController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _backendDirController;
  late final FocusNode _quizFocus;
  late final FocusNode _newsFocus;
  late final FocusNode _baseUrlFocus;
  late final FocusNode _backendDirFocus;

  @override
  void initState() {
    super.initState();
    _provider = context.read<SettingsProvider>();
    final s = _provider.settings;
    _quizController = TextEditingController(text: s.quizTopic);
    _newsController = TextEditingController(text: s.newsScope);
    _baseUrlController = TextEditingController(text: s.baseUrl);
    _backendDirController = TextEditingController(text: s.backendDir);
    _quizFocus = FocusNode()..addListener(_onQuizBlur);
    _newsFocus = FocusNode()..addListener(_onNewsBlur);
    _baseUrlFocus = FocusNode();
    _backendDirFocus = FocusNode();
    // 只在输入框没有焦点时把提供者的值同步进来：
    // 既覆盖"本地设置加载完成"的初始化，又避免打字打到一半
    // 被 checkConnection 定时 notifyListeners 重建冲掉
    _provider.addListener(_syncFromProvider);
  }

  /// 出题领域失焦即保存（改完点别处就存，不用非按回车）
  void _onQuizBlur() {
    if (_quizFocus.hasFocus) return;
    final value = _quizController.text.trim();
    if (value.isNotEmpty && value != _provider.settings.quizTopic) {
      _provider.setQuizTopic(value);
    }
  }

  /// 新闻范围失焦即保存
  void _onNewsBlur() {
    if (_newsFocus.hasFocus) return;
    final value = _newsController.text.trim();
    if (value.isNotEmpty && value != _provider.settings.newsScope) {
      _provider.setNewsScope(value);
    }
  }

  void _syncFromProvider() {
    final s = _provider.settings;
    if (!_quizFocus.hasFocus && _quizController.text != s.quizTopic) {
      _quizController.text = s.quizTopic;
    }
    if (!_newsFocus.hasFocus && _newsController.text != s.newsScope) {
      _newsController.text = s.newsScope;
    }
    if (!_baseUrlFocus.hasFocus && _baseUrlController.text != s.baseUrl) {
      _baseUrlController.text = s.baseUrl;
    }
    if (!_backendDirFocus.hasFocus &&
        _backendDirController.text != s.backendDir) {
      _backendDirController.text = s.backendDir;
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_syncFromProvider);
    _quizController.dispose();
    _newsController.dispose();
    _baseUrlController.dispose();
    _backendDirController.dispose();
    _quizFocus.dispose();
    _newsFocus.dispose();
    _baseUrlFocus.dispose();
    _backendDirFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // 后端连接
          _Section(title: '服务器', icon: Icons.dns_outlined, children: [
            TextField(
              controller: _baseUrlController,
              focusNode: _baseUrlFocus,
              decoration: const InputDecoration(
                labelText: '后端地址',
                hintText: 'http://localhost:8000',
              ),
              onSubmitted: (value) => settings.setBaseUrl(value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backendDirController,
              focusNode: _backendDirFocus,
              decoration: const InputDecoration(
                labelText: '后端目录',
                hintText: r'D:\My_Elysia_ai\backend',
                helperText: '注册开机自启动时需要',
              ),
              onSubmitted: (value) => settings.setBackendDir(value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  settings.isConnected ? Icons.check_circle : Icons.error,
                  color: settings.isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  settings.isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    color: settings.isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => settings.checkConnection(),
                  child: const Text('重新检查'),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 20),

          // 模型选择
          _Section(title: '模型', icon: Icons.smart_toy_outlined, children: [
            RadioGroup<String>(
              groupValue: settings.settings.model,
              onChanged: (String? v) => settings.setModel(v!),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('deepseek-chat'),
                    subtitle: const Text('标准模型（推荐）'),
                    value: 'deepseek-chat',
                  ),
                  RadioListTile<String>(
                    title: const Text('deepseek-reasoner'),
                    subtitle: const Text('推理模型（更深度的分析）'),
                    value: 'deepseek-reasoner',
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 每日问答
          _Section(title: '每日问答', icon: Icons.quiz_outlined, children: [
            TextField(
              controller: _quizController,
              focusNode: _quizFocus,
              decoration: const InputDecoration(
                labelText: '出题领域',
                hintText: '前后端全栈',
                helperText: '多个领域用「和」分隔会交替出题；改完点别处自动保存',
              ),
              onSubmitted: (value) => settings.setQuizTopic(value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GradientButton(
                label: settings.generatingQuiz ? '出题中…' : '按此领域立即出题',
                icon: Icons.auto_awesome,
                loading: settings.generatingQuiz,
                onPressed: settings.generatingQuiz
                    ? null
                    : () async {
                        final (ok, msg) =
                            await settings.generateQuizNow(_quizController.text);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                        if (ok) context.read<DailyProvider>().loadToday();
                      },
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 每日新闻
          _Section(title: '每日新闻', icon: Icons.newspaper_outlined, children: [
            TextField(
              controller: _newsController,
              focusNode: _newsFocus,
              decoration: const InputDecoration(
                labelText: '新闻范围',
                hintText: 'AI',
                helperText: '改完点别处就自动保存；点下方按钮可立即重抓',
              ),
              onSubmitted: (value) => settings.setNewsScope(value),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GradientButton(
                label: settings.refreshingNews ? '抓取中…可能要几十秒' : '按此范围立即刷新',
                icon: Icons.refresh,
                loading: settings.refreshingNews,
                onPressed: settings.refreshingNews
                    ? null
                    : () async {
                        final (ok, msg) =
                            await settings.refreshNewsNow(_newsController.text);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                        if (ok) context.read<DailyProvider>().loadNews();
                      },
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // 外观
          _Section(title: '外观', icon: Icons.palette_outlined, children: [
            SwitchListTile(
              title: const Text('深色模式'),
              value: settings.settings.isDarkMode,
              onChanged: (v) => settings.toggleDarkMode(v),
            ),
          ]),

          const SizedBox(height: 20),

          // 开机自启动
          _Section(title: '开机自启动', icon: Icons.power_settings_new, children: [
            SwitchListTile(
              title: const Text('开机自动启动'),
              subtitle: const Text('开机先启动后端服务，两秒后启动本应用'),
              value: settings.settings.autoStart,
              onChanged: (v) async {
                final error = await settings.setAutoStart(v);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                }
              },
            ),
          ]),
        ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
