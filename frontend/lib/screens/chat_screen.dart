import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';
import '../screens/conversation_list_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          chatProvider.currentConversation?.title ?? AppConfig.appFullName,
          style: theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '你好，我是 ${AppConfig.appName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '我整合多种心理学方法，为你提供专业的心理支持。\n随时可以说说你心里的想法，我在这里听你说。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '我提供的是心理支持而非医疗诊断。如有紧急情况，请拨打 24 小时心理援助热线：400-161-9995',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ChatProvider chatProvider) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.psychology, size: 40,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  AppConfig.appFullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  AppConfig.appSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_comment),
            title: const Text('新建对话'),
            onTap: () {
              Navigator.pop(context);
              chatProvider.createNewConversation();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('历史对话'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConversationListScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
