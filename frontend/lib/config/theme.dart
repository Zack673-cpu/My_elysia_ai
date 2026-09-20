import 'package:flutter/material.dart';

/// 全局主题：粉嫩温馨系
class AppTheme {
  // ===== 品牌色 =====
  /// 主粉
  static const Color primaryColor = Color(0xFFF06292);
  /// 渐变亮粉
  static const Color pinkLight = Color(0xFFFF9EC8);
  /// 渐变深粉
  static const Color pinkDeep = Color(0xFFF06292);
  /// 暖桃（辅助点缀）
  static const Color peach = Color(0xFFFFB6C1);

  // ===== 背景渐变 =====
  static const Color bgTopLight = Color(0xFFFFF6FB);
  static const Color bgBottomLight = Color(0xFFFFE9F2);
  static const Color bgTopDark = Color(0xFF2A1B24);
  static const Color bgBottomDark = Color(0xFF1E1117);

  // ===== 圆角体系 =====
  static const double radiusCard = 22;
  static const double radiusInput = 16;

  /// 品牌渐变（按钮 / 气泡 / 头像光晕统一使用）
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pinkLight, pinkDeep],
  );

  /// 禁用态渐变
  static const LinearGradient disabledGradient = LinearGradient(
    colors: [Color(0xFFE0C6D1), Color(0xFFD9B6C3)],
  );

  static ThemeData lightTheme = _build(Brightness.light);

  static ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 背景交给全局 GradientBackground，Scaffold 保持透明
      scaffoldBackgroundColor: Colors.transparent,
      // 全 App 统一圆润可爱字体（阿里妈妈方圆体），生僻字回退到系统字体
      fontFamily: 'AlimamaFangYuanTiVF',
      fontFamilyFallback: const ['Microsoft YaHei'],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isLight ? const Color(0xFF7A3B52) : scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? const Color(0xFFFFFDFE) : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: primaryColor.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder()),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? primaryColor.withValues(alpha: 0.06)
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: isLight
                ? primaryColor.withValues(alpha: 0.18)
                : scheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.7)
              : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF7A3B52) : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isLight ? const Color(0xFFFFFDFE) : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(radiusCard),
            bottomRight: Radius.circular(radiusCard),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
      // 干脆利落的快速淡入切页，避免默认缩放动画在 Windows 上发飘
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SnappyPageTransitionsBuilder(),
          TargetPlatform.iOS: _SnappyPageTransitionsBuilder(),
          TargetPlatform.windows: _SnappyPageTransitionsBuilder(),
          TargetPlatform.macOS: _SnappyPageTransitionsBuilder(),
          TargetPlatform.linux: _SnappyPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SnappyPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 快速淡入 + 轻微上移的切页动画
class _SnappyPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SnappyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
