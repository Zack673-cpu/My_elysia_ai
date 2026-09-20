import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 粉色渐变胶囊按钮：主操作按钮统一用它，
/// 带柔和粉光投影，比系统默认按钮更有质感。
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final gradient = enabled ? AppTheme.brandGradient : AppTheme.disabledGradient;

    Widget content = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          );

    final visual = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: content,
    );

    final button = enabled
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: visual,
          )
        : visual;

    return expand
        ? SizedBox(width: double.infinity, child: Center(child: button))
        : button;
  }
}
