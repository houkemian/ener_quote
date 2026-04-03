import 'package:flutter/material.dart';

/// 亮色 SaaS 全局语义色（与 [AppTheme] 对齐）。
abstract final class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  /// 正文与标题（白底上的深色字）
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF64748B);

  /// 品牌主色：现代蓝（Primary）
  static const Color primary = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// 品牌辅色：暖金黄（Secondary / PRO 强调）
  static const Color secondary = Color(0xFFF59E0B);
  static const Color onSecondary = Color(0xFF292524);

  /// 成功 / 正向现金流（图表柱、KPI 点缀）
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);

  /// 图表网格线、弱分割线
  static const Color chartGrid = Color(0xFFE2E8F0);

  /// 下拉菜单浮层、对话框衬底
  static const Color overlayScrim = Color(0x66000000);
}
