import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../widgets/gradient_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('关于')),
        body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo & Title
          Center(
            child: Column(
              children: [
                // 渐变光环头像
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 46,
                    backgroundImage: AssetImage(AppConfig.aiAvatarAsset),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppConfig.appFullName, style: theme.textTheme.headlineMedium),
                Text('你的全能伙伴~♪',
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
                      
                      const SizedBox(width: 8),
                      Text('说明🎶',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '目前处于第一阶段，功能还不完善~',
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
      ),
    );
  }
}

