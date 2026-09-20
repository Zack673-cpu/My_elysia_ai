import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/message.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return _MessageEntrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              _AvatarRing(
                radius: 18,
                child: const CircleAvatar(
                  radius: 15,
                  backgroundImage: AssetImage(AppConfig.aiAvatarAsset),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: isUser
                  ? _UserBubble(message: message)
                  : _AiBubble(message: message, theme: theme),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              _AvatarRing(
                radius: 18,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                  child: Icon(Icons.person,
                      size: 16, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 头像渐变光环
class _AvatarRing extends StatelessWidget {
  final double radius;
  final Widget child;

  const _AvatarRing({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.brandGradient,
      ),
      child: ClipOval(child: child),
    );
  }
}

/// 用户消息：粉色渐变气泡 + 右下尾巴
class _UserBubble extends StatelessWidget {
  final Message message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
        // 尾巴
        Positioned(
          right: -5,
          bottom: 0,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// AI 消息：暖白气泡 + 粉边 + 左下尾巴
class _AiBubble extends StatelessWidget {
  final Message message;
  final ThemeData theme;

  const _AiBubble({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : const Color(0xFFFFFDFE);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
            ),
          ),
        ),
        // 尾巴
        Positioned(
          left: -5,
          bottom: 0,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border(
                  left: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.22),
                  ),
                  top: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 新消息入场动效：淡入 + 轻微上浮。
/// State 挂在元素上，只有新消息（新元素）创建时才播放，
/// 流式更新（同一元素重建）不会反复触发。
class _MessageEntrance extends StatefulWidget {
  final Widget child;

  const _MessageEntrance({required this.child});

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
