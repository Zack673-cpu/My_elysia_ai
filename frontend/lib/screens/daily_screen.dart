import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/daily.dart';
import '../providers/daily_provider.dart';

/// 每日页面：上半部分是今日问答，往下划是每日新闻
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DailyProvider>();
      provider.loadToday();
      provider.loadNews();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _submit(DailyProvider provider) {
    if (provider.submitting) return;
    provider.submitAnswer(_answerController.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('每日')),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadToday();
          await provider.loadNews();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildQuizCard(context, provider),
            const SizedBox(height: 32),
            _buildNewsSection(context, provider),
          ],
        ),
      ),
    );
  }

  // ===== 每日问答卡片 =====

  Widget _buildQuizCard(BuildContext context, DailyProvider provider) {
    final theme = Theme.of(context);
    final state = provider.state;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: state == null
            ? _buildQuizLoading(provider)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuizHeader(context, state),
                  const SizedBox(height: 20),
                  Text(
                    state.question,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 24),
                  if (!state.answered)
                    _buildAnswerInput(context, provider)
                  else ...[
                    _buildAnsweredSection(context, state),
                    if (state.decision != null) ...[
                      const SizedBox(height: 20),
                      _buildDecisionCard(context, provider, state),
                    ],
                    if (state.isDone && state.dueCount > 0) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: provider.loadingQuestion
                              ? null
                              : () {
                                  _answerController.clear();
                                  provider.loadToday(forceNew: true);
                                },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text('再来一题（还有 ${state.dueCount} 道待复习）'),
                        ),
                      ),
                    ],
                  ],
                  if (provider.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildQuizLoading(DailyProvider provider) {
    if (provider.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          provider.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildQuizHeader(BuildContext context, DailyState state) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text('今日问答', style: theme.textTheme.titleMedium),
        const SizedBox(width: 12),
        _chip(
          context,
          state.isReview ? '复习 · Lv.${state.level}' : '新题',
          state.isReview
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.primaryContainer,
        ),
        const Spacer(),
        if (state.dueCount > 0)
          Text(
            '待复习 ${state.dueCount}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  /// 答题输入区：回车提交，Shift+回车换行
  Widget _buildAnswerInput(BuildContext context, DailyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableActionDetector(
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            },
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _submit(provider);
                    return null;
                  },
                ),
              },
              child: TextField(
                controller: _answerController,
                maxLines: null,
                minLines: 3,
                enabled: !provider.submitting,
                decoration: const InputDecoration(
                  hintText: '写下你的答案…（回车提交，Shift+回车换行）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: provider.submitting ? null : () => _submit(provider),
            icon: provider.submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(provider.submitting ? 'AI 评估中…' : '提交'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnsweredSection(BuildContext context, DailyState state) {
    final theme = Theme.of(context);
    final gradeColor = switch (state.grade) {
      'correct' => Colors.green,
      'wrong' => theme.colorScheme.error,
      _ => Colors.orange,
    };
    final gradeText = switch (state.grade) {
      'correct' => '答对了',
      'wrong' => '没答上来',
      _ => '部分正确',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 用户答案
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            state.userAnswer ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 18),
        // AI 反馈
        Row(
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('AI 反馈', style: theme.textTheme.titleSmall),
            const SizedBox(width: 10),
            _chip(context, gradeText, gradeColor.withValues(alpha: 0.15)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          state.feedback ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
        ),
        // 复习建议（独立展示，不属于十句反馈）
        if ((state.suggestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.suggestion!,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===== 决策弹窗（页内卡片） =====

  Widget _buildDecisionCard(
      BuildContext context, DailyProvider provider, DailyState state) {
    final theme = Theme.of(context);
    final (title, primary, secondary) = switch (state.decision) {
      'new_question' => (
          '这道新题答完了，要把它放进复习计划吗？',
          ('投入轮回历练...', 'join_review'),
          ('秒了', 'skip'),
        ),
      'review_partial' => (
          '这题不太好简单判对错，接下来怎么安排？',
          ('再勤快些吧~', 'decrease'),
          ('可以放松一些', 'increase'),
        ),
      'mastery_exam' => (
          '这个知识点已经复习很多次了呢，还需要再来一次吗♪',
          ('再次踏上轮回...', 'reset'),
          ('我已臻至化境！', 'master'),
        ),
      _ => ('', ('', ''), ('', '')),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: provider.submitting
                      ? null
                      : () => provider.resolve(primary.$2),
                  child: Text(primary.$1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: provider.submitting
                      ? null
                      : () => provider.resolve(secondary.$2),
                  child: Text(secondary.$1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 每日新闻 =====

  Widget _buildNewsSection(BuildContext context, DailyProvider provider) {
    final theme = Theme.of(context);
    final news = provider.news;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text('每日新闻', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '只保留最近一周',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (news.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '暂无新闻，后端启动时会自动抓取',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          for (final item in news) ...[
            _NewsTile(item: item),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  final NewsItem item;

  const _NewsTile({required this.item});

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openUrl(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.summary,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.open_in_new,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.url,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
