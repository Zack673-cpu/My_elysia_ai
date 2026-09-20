import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../config/theme.dart';
import '../widgets/gradient_background.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final theme = Theme.of(context);

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('历史对话')),
        body: chatProvider.conversations.isEmpty
            ? const _EmptyState()
            : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final conv = chatProvider.conversations[index];
                final date = DateFormat('MM/dd HH:mm').format(conv.updatedAt);

                return Dismissible(
                  key: Key(conv.conversationId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    chatProvider.deleteConversation(conv.conversationId);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainer
                          : const Color(0xFFFFFDFE),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.brandGradient,
                        ),
                        child: const Center(
                          child: Icon(Icons.chat_bubble_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      title: Text(
                        conv.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '$date · ${conv.metadata.messageCount} 条消息',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                      onTap: () {
                        chatProvider.switchConversation(conv.conversationId);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有对话记录哦~',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
