import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';
import '../screens/conversation_list_screen.dart';
import '../screens/daily_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';
import '../widgets/gradient_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    // 监听消息变化自动滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatProvider.isStreaming || chatProvider.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            chatProvider.currentConversation?.title ?? AppConfig.appFullName,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        actions: [
          // 压缩上下文（对话较长时用，防止上下文过长导致响应慢）
          if (chatProvider.currentConversation != null)
            IconButton(
              tooltip: '压缩上下文',
              icon: const Icon(Icons.compress, size: 20),
              onPressed: () async {
                final message = await chatProvider.compressContext();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
            ),
          // 连接状态指示
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: settingsProvider.isConnected
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, chatProvider),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: chatProvider.messages.isEmpty && !chatProvider.isStreaming
                ? _buildWelcome(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatProvider.messages.length +
                        (chatProvider.isStreaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < chatProvider.messages.length) {
                        return MessageBubble(
                            message: chatProvider.messages[index]);
                      }
                      // 流式回复指示器
                      return TypingIndicator(
                          content: chatProvider.streamingContent);
                    },
                  ),
          ),

          // 错误提示
          if (chatProvider.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),

          // 输入栏
          ChatInput(
            isLoading: chatProvider.isLoading,
            onSend: (content) => chatProvider.sendMessage(content),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = context.watch<ChatProvider>();
    const suggestions = [
      (Icons.auto_awesome, '教我一个小知识吧♪'),
      (Icons.movie_outlined, '给我推荐一部好看的番'),
      (Icons.newspaper, '今天有什么新鲜事？'),
      (Icons.favorite_outline, '陪我聊聊最近的心情'),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变光环 + 柔光头像
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.22),
                    theme.colorScheme.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  radius: 36,
                  backgroundImage: AssetImage(AppConfig.aiAvatarAsset),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '嗨~ 我是昔涟♪',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : const Color(0xFF7A3B52),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '和我聊聊天吧，我什么都会听你说的♪',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '开发中，Cryene 阶段',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            // 建议话题
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final (icon, label) in suggestions)
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => chatProvider.sendMessage(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainer
                            : const Color(0xFFFFFDFE),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ChatProvider chatProvider) {
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, String? subtitle, VoidCallback onTap) {
      return ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: theme.textTheme.bodySmall),
        onTap: onTap,
      );
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 渐变头部
          Container(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppTheme.radiusCard),
                bottomRight: Radius.circular(AppTheme.radiusCard),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage(AppConfig.aiAvatarAsset),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConfig.appFullName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppConfig.appSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          tile(Icons.add_comment, '新建对话', null, () {
            Navigator.pop(context);
            chatProvider.createNewConversation();
          }),
          tile(Icons.history, '历史对话', null, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ConversationListScreen()),
            );
          }),
          tile(Icons.today, '每日', '每日问答与新闻', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyScreen()),
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Divider(),
          ),
          tile(Icons.settings, '设置', null, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }),
          tile(Icons.info_outline, '关于', null, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          }),
        ],
      ),
    );
  }
}
