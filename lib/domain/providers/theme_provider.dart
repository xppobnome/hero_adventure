import 'package:flutter/material.dart';

/// 奥特曼主题 (光之守护) 配色常量。
///
/// 集中定义主题色，供全 App 复用，避免散落硬编码。
/// 主基调：科幻深空蓝 + 太空银 + 计时器蓝 + 能量金，
/// 红色仅作为「能量/生命」点缀，不做大面积铺底，避免生硬的「红色咸蛋超人」感。
class UltramanTheme {
  UltramanTheme._();

  /// 能量红 (仅作点缀，如生命值/强调文字)
  static const Color red = Color(0xFFE6483D);

  /// 太空银
  static const Color silver = Color(0xFFC0C0C0);

  /// 计时器蓝
  static const Color blue = Color(0xFF00A0E9);

  /// 深空底色 (科幻感深色背景)
  static const Color deepSpace = Color(0xFF0B1026);

  /// 星云紫 (背景渐变辅助)
  static const Color nebula = Color(0xFF1B2A6B);

  /// 能量金色
  static const Color gold = Color(0xFFFFC107);

  /// 构建奥特曼主题 ThemeData。
  static ThemeData buildTheme() {
    return ThemeData(
      primaryColor: blue,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: const ColorScheme.light(
        primary: blue,
        secondary: blue,
        tertiary: gold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1026),
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
