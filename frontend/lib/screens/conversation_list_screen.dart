import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../config/theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史对话'),
      ),
      body: chatProvider.conversations.isEmpty
          ? const Center(child: Text('还没有对话记录'))
          : ListView.separated(
              itemCount: chatProvider.conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conv = chatProvider.conversations[index];
                final date = DateFormat('MM/dd HH:mm').format(conv.updatedAt);

                return Dismissible(
                  key: Key(conv.conversationId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: theme.colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    chatProvider.deleteConversation(conv.conversationId);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    title: Text(conv.title, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '$date · ${conv.metadata.messageCount} 条消息',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () {
                      chatProvider.switchConversation(conv.conversationId);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }
}
