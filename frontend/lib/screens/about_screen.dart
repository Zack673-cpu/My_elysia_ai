import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo & Title
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology,
                      size: 64, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(AppConfig.appFullName, style: theme.textTheme.headlineMedium),
                Text('你的心灵成长伙伴',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 8),
                Text('v0.1.0', style: theme.textTheme.bodySmall),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Disclaimer
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('重要声明',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本应用提供的是心理支持和教育信息，不能替代专业的心理治疗或医疗诊断。'
                    '如果你正在经历心理危机，请立即联系专业机构：\n\n'
                    '• 全国 24 小时心理援助热线：400-161-9995\n'
                    '• 北京心理危机研究与干预中心：010-82951332\n'
                    '• 生命热线：400-821-1215\n'
                    '• 紧急情况请拨打：110 或 120',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Powered by DeepSeek LLM',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

