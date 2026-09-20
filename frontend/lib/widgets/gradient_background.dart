import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 全局柔粉渐变背景：挂在 MaterialApp.builder 上，
/// 让所有页面自动获得粉嫩渐变 + 角落柔光。
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [AppTheme.bgTopDark, AppTheme.bgBottomDark]
              : [AppTheme.bgTopLight, AppTheme.bgBottomLight],
        ),
      ),
      child: Stack(
        children: [
          // 左上柔光
          Positioned(
            top: -100,
            left: -80,
            child: _Glow(
              radius: 240,
              color: AppTheme.pinkLight.withValues(alpha: dark ? 0.10 : 0.30),
            ),
          ),
          // 右下柔光
          Positioned(
            bottom: -120,
            right: -100,
            child: _Glow(
              radius: 280,
              color: AppTheme.peach.withValues(alpha: dark ? 0.08 : 0.26),
            ),
          ),
          // 中上一点淡粉光，提亮
          Positioned(
            top: 80,
            right: -60,
            child: _Glow(
              radius: 160,
              color: AppTheme.primaryColor.withValues(alpha: dark ? 0.06 : 0.10),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 径向渐变的柔光圆，从中心颜色淡出到透明
class _Glow extends StatelessWidget {
  final double radius;
  final Color color;

  const _Glow({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
