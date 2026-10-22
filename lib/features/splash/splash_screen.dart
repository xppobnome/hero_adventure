import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/utils/app_display.dart';
import '../../core/utils/audio_manager.dart';
import '../../core/widgets/ultraman_visuals.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/theme_provider.dart';

/// 开屏启动页：展示奥特曼主题启动动画 + 应用名，短暂停留后自动进入主界面。
///
/// 视觉上营造「光之巨人变身」的游戏感：星空背景 + 多层旋转能量光环 +
/// 脉冲波纹 + 环绕粒子 + 中心图标缩放弹入，配合启动音效。
/// 若用户开启了「自定义显示」，则展示自定义头像与名字（儿童头像 / 昵称）。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // 主控制器：驱动整体进出场 (缩放 + 淡入)
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // 旋转光环控制器 (无限循环)
  late final AnimationController _ringController;

  // 脉冲波纹控制器 (无限循环)
  late final AnimationController _pulseController;

  // 粒子控制器 (无限循环)
  late final AnimationController _particleController;

  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    // 首帧后播放启动音效（确保音频会话已就绪）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _playStartupAudio());
  }

  Future<void> _playStartupAudio() async {
    if (_audioStarted) return;
    _audioStarted = true;
    try {
      // 不 await，避免阻塞启动动画；音效后台播放。
      unawaited(AudioManager().playStartup());
    } catch (_) {
      // 忽略启动音效失败
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ringController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final family = ref.watch(familyProfileProvider);
    final child =
        family?.children.isNotEmpty == true ? family!.children.first : null;

    // 是否用自定义显示内容。
    final useCustom = AppDisplay.useCustomDisplay(storage);
    final appName =
        useCustom ? AppDisplay.resolveName(storage, child) : '小朋友冒险计划';
    final iconPath =
        useCustom ? AppDisplay.resolveIconPath(storage, child) : '';

    return Scaffold(
      backgroundColor: UltramanTheme.deepSpace,
      body: Stack(
        children: [
          // 星空背景
          const Positioned.fill(child: UltramanStarfield()),
          // 全屏特效层 (旋转光环 + 脉冲波纹 + 粒子)
          Positioned.fill(
            child: _EnergyBackground(
              ringController: _ringController,
              pulseController: _pulseController,
              particleController: _particleController,
            ),
          ),
          // 中心内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 英雄盾牌图标 / 自定义头像 + 光环动画
                ScaleTransition(
                  scale: _scaleAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildIcon(useCustom, iconPath),
                  ),
                ),
                SizedBox(height: 30.h),
                // 应用名 (扫光渐显)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _ShimmerText(text: appName),
                ),
                SizedBox(height: 44.h),
                // 能量加载进度条 (替代圆形进度)
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _EnergyLoadingBar(controller: _controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 图标：自定义头像（若启用且有图片）→ 圆形头像；否则默认应用图标 icon.png。
  Widget _buildIcon(bool useCustom, String iconPath) {
    final image = (useCustom && iconPath.isNotEmpty && File(iconPath).existsSync())
        ? Image.file(
            File(iconPath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _defaultIconImage(),
          )
        : Image.asset(
            'assets/icon.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _fallbackShieldIcon(),
          );

    return Container(
      width: 150.w,
      height: 150.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: UltramanTheme.blue.withValues(alpha: 0.7),
            blurRadius: 50,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: UltramanTheme.gold.withValues(alpha: 0.35),
            blurRadius: 70,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }

  Widget _defaultIconImage() {
    return Image.asset(
      'assets/icon.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _fallbackShieldIcon(),
    );
  }

  /// 图标资源缺失时的兜底：程序绘制盾牌。
  Widget _fallbackShieldIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00A0E9), Color(0xFF0B1026)],
        ),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 72.r,
      ),
    );
  }
}

/// 全屏能量特效背景：旋转光环 + 脉冲波纹 + 环绕能量粒子。
///
/// 用 CustomPainter 逐帧绘制，营造「能量汇聚 / 变身」的科幻氛围。
class _EnergyBackground extends StatelessWidget {
  final AnimationController ringController;
  final AnimationController pulseController;
  final AnimationController particleController;

  const _EnergyBackground({
    required this.ringController,
    required this.pulseController,
    required this.particleController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [ringController, pulseController, particleController],
      ),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _EnergyBackgroundPainter(
            ringT: ringController.value,
            pulseT: pulseController.value,
            particleT: particleController.value,
          ),
        );
      },
    );
  }
}

class _EnergyBackgroundPainter extends CustomPainter {
  final double ringT;
  final double pulseT;
  final double particleT;

  _EnergyBackgroundPainter({
    required this.ringT,
    required this.pulseT,
    required this.particleT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = size.shortestSide;

    _drawRotatingRings(canvas, center, shortest);
    _drawPulseRings(canvas, center, shortest);
    _drawOrbitingParticles(canvas, center, shortest);
  }

  /// 旋转的科幻能量光环 (两三层不同角度、不同速度的圆弧)。
  void _drawRotatingRings(Canvas canvas, Offset center, double shortest) {
    final baseR = shortest * 0.30;
    const ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final radius = baseR * (1 + i * 0.28);
      final speed = 1 + i * 0.6;
      final rot = ringT * math.pi * 2 * speed;
      final arcSweep = math.pi * (0.9 + i * 0.25);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (i == 0 ? 3.0 : 2.0)
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            (i.isEven ? UltramanTheme.blue : UltramanTheme.gold)
                .withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        0,
        arcSweep,
        false,
        paint,
      );
      // 光环头部亮点
      final headAngle = arcSweep;
      final headPos = Offset(
        math.cos(headAngle) * radius,
        math.sin(headAngle) * radius,
      );
      final headPaint = Paint()
        ..color = (i.isEven ? UltramanTheme.blue : UltramanTheme.gold)
            .withValues(alpha: 0.95);
      canvas.drawCircle(headPos, 4.5, headPaint);
      canvas.restore();
    }
  }

  /// 从中心向外扩散的脉冲波纹。
  void _drawPulseRings(Canvas canvas, Offset center, double shortest) {
    const ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final t = (pulseT + i / ringCount) % 1.0;
      final radius = shortest * 0.22 + shortest * 0.34 * t;
      final alpha = (1 - t) * 0.5;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = UltramanTheme.blue.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }
  }

  /// 环绕中心旋转的能量粒子。
  void _drawOrbitingParticles(Canvas canvas, Offset center, double shortest) {
    const particleCount = 24;
    final baseR = shortest * 0.30;
    for (int i = 0; i < particleCount; i++) {
      final angle =
          (math.pi * 2 / particleCount) * i + particleT * math.pi * 2;
      // 半径在 baseR 附近轻微摆动，形成立体感
      final wobble = math.sin(particleT * math.pi * 2 + i) * shortest * 0.04;
      final radius = baseR + shortest * 0.16 + wobble;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final size = 1.5 + (i % 3) * 0.8;
      final color = (i % 4 == 0) ? UltramanTheme.gold : UltramanTheme.blue;
      final alpha = 0.4 + 0.5 * ((math.sin(particleT * math.pi * 2 + i) + 1) / 2);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(p, size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyBackgroundPainter oldDelegate) =>
      oldDelegate.ringT != ringT ||
      oldDelegate.pulseT != pulseT ||
      oldDelegate.particleT != particleT;
}

/// 发光文字：应用名带蓝色光晕 + 金色外发光，营造「光之巨人」的质感。
class _ShimmerText extends StatelessWidget {
  final String text;
  const _ShimmerText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 28.sp,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 2,
        shadows: [
          Shadow(
            color: UltramanTheme.blue.withValues(alpha: 0.9),
            blurRadius: 18,
          ),
          Shadow(
            color: UltramanTheme.blue.withValues(alpha: 0.6),
            blurRadius: 36,
          ),
          Shadow(
            color: UltramanTheme.gold.withValues(alpha: 0.35),
            blurRadius: 50,
          ),
        ],
      ),
    );
  }
}

/// 能量加载进度条 (跟随主动画进度，替代圆形进度指示器)。
class _EnergyLoadingBar extends StatelessWidget {
  final AnimationController controller;
  const _EnergyLoadingBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          width: 180.w,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 180.w * t,
              height: 5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A0E9), Color(0xFF9BE7FF)],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: UltramanTheme.blue.withValues(alpha: 0.7),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
