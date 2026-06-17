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

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          // 外观
          _Section(title: '外观', children: [
            SwitchListTile(
              title: const Text('深色模式'),
              value: settings.settings.isDarkMode,
              onChanged: (v) => settings.toggleDarkMode(v),
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


