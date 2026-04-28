// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  /// 主品牌蓝（个人主页头图、底栏选中态、进度等）
  static const Color primary = Color(0xFF1E40AF);

  static const Color pageBackground = Color(0xFFFAFBFC);
  static const Color background = pageBackground;
  static const Color textPrimary = Color(0xFF0F172A);
}

class AppTextStyles {
  // 定义字体字号，从 Figma 取值
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
}

// 统一的主题配置（与 ColorScheme 对齐，子页面用 Theme 取色避免硬编码）
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        surface: AppColors.pageBackground,
        surfaceContainerHigh: Colors.white,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFEFF6FF),
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: const Color(0xFF64748B),
        outline: const Color(0xFFE2E8F0),
        outlineVariant: const Color(0xFFE2E8F0),
        tertiary: const Color(0xFFEA580C),
        onTertiary: Colors.white,
      ),
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.pageBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineMedium: AppTextStyles.heading,
    bodyMedium: AppTextStyles.body,
  ),
);
