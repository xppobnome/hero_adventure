import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/hero_system.dart';
import '../../domain/providers/theme_provider.dart';
import 'ultraman_visuals.dart';

/// 英雄展示弹窗 (居中)：展示英雄立绘 + 名称 + 称号 + 高级特效。
///
/// 与图鉴选择英雄时一致的弹窗，供图鉴点选、打卡等场景复用。
/// 自带循环动画特效 (光环扩散、环绕粒子、能量光柱、立绘浮动)。
class HeroShowcaseDialog extends StatefulWidget {
  final HeroEntry hero;

  /// 底部标签文字 (默认「已出战！」)。
  final String badgeText;

  const HeroShowcaseDialog({
    super.key,
    required this.hero,
    this.badgeText = '已出战！',
  });

  @override
  State<HeroShowcaseDialog> createState() => _HeroShowcaseDialogState();
}

class _HeroShowcaseDialogState extends State<HeroShowcaseDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    final color = Color(int.parse('FF${hero.colorHex}', radix: 16));
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final floatY = -6 * math.sin(t * math.pi * 2);
          final breatheScale = 1.0 + 0.04 * math.sin(t * math.pi * 2);
          return Container(
            width: 300.w,
            padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25 + 0.20 * math.sin(t * math.pi * 2)),
                  blurRadius: 50,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220.w,
                  height: 220.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _HeroAuraPainter(progress: t, color: color),
                        ),
                      ),
                      Transform.scale(
                        scale: breatheScale,
                        child: Container(
                          width: 150.w,
                          height: 150.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.withValues(alpha: 0.45),
                                color.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, floatY),
                        child: UltramanHeroAvatar(size: 160.w, hero: hero),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  hero.name,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  hero.title,
                  style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: UltramanTheme.gold,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    widget.badgeText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 英雄展示弹窗的特效绘制器：扩散光环 + 环绕粒子 + 底部能量光柱。
class _HeroAuraPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeroAuraPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;

    // 三层扩散光环
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = maxRadius * (0.35 + 0.65 * phase);
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.5;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + (1.0 - phase) * 2.0
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, ring);
    }

    // 环绕粒子
    final particleCount = 12;
    for (int i = 0; i < particleCount; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi * 2 / particleCount);
      final orbitRadius = maxRadius * 0.82;
      final p = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle),
      );
      final particle = Paint()..color = color.withValues(alpha: 0.9);
      canvas.drawCircle(p, 3.0, particle);
      final tail = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(p, 6.0, tail);
    }

    // 底部能量光柱
    final beamPaint = Paint()..color = color.withValues(alpha: 0.35);
    final beamY = size.height * 0.78 - (progress * size.height * 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, beamY),
          width: size.width * 0.5,
          height: size.height * 0.18,
        ),
        const Radius.circular(40),
      ),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroAuraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
