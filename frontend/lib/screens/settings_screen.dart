import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 后端连接
          _Section(title: '服务器', children: [
            TextField(
              controller: TextEditingController(text: settings.settings.baseUrl),
              decoration: const InputDecoration(
                labelText: '后端地址',
                hintText: 'http://localhost:8000',
              ),
              onSubmitted: (value) => settings.setBaseUrl(value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller:
                  TextEditingController(text: settings.settings.backendDir),
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
          _Section(title: '模型', children: [
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
          _Section(title: '每日问答', children: [
            TextField(
              controller:
                  TextEditingController(text: settings.settings.quizTopic),
              decoration: const InputDecoration(
                labelText: '出题领域',
                hintText: '前后端全栈',
                helperText: '没有到期复习题时，AI 按这个领域出新题',
              ),
              onSubmitted: (value) => settings.setQuizTopic(value),
            ),
          ]),

          const SizedBox(height: 20),

          // 每日新闻
          _Section(title: '每日新闻', children: [
            TextField(
              controller:
                  TextEditingController(text: settings.settings.newsScope),
              decoration: const InputDecoration(
                labelText: '新闻范围',
                hintText: 'AI',
                helperText: '后端开机启动时按这个范围抓取最新新闻',
              ),
              onSubmitted: (value) => settings.setNewsScope(value),
            ),
          ]),

          const SizedBox(height: 20),

          // 外观
          _Section(title: '外观', children: [
            SwitchListTile(
              title: const Text('深色模式'),
              value: settings.settings.isDarkMode,
              onChanged: (v) => settings.toggleDarkMode(v),
            ),
          ]),

          const SizedBox(height: 20),

          // 开机自启动
          _Section(title: '开机自启动', children: [
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
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}
