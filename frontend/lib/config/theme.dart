import 'package:flutter/material.dart';

class AppTheme {
  // 品牌颜色
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF48C6EF);
  static const Color accentColor = Color(0xFFFF6B9D);

  // 阶段颜色
  static const Color demugoColor = Color(0xFF81C784);   // 绿色 — 初始萌芽
  static const Color cryeneColor = Color(0xFF64B5F6);   // 蓝色 — 水晶清澈
  static const Color elysiaColor = Color(0xFFCE93D8);   // 紫色 — 极乐净土

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
  );

  static Color getStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'demugo':
        return demugoColor;
      case 'cryene':
        return cryeneColor;
      case 'elysia':
        return elysiaColor;
      default:
        return primaryColor;
    }
  }
}
