import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../domain/hero_system.dart';

/// 奥特曼主题纯代码绘制视觉组件。
///
/// 由于 assets 目录暂无外部图片/动画资源，这里用 CustomPainter 绘制
/// 科幻感星空背景、怪兽与光之巨人的占位视觉，保证可脱离资源文件运行。
/// 后续接入真实切图/Lottie 时，替换对应 widget 即可。

/// 科幻星空背景 (深空 + 星点 + 星云)。
class UltramanStarfield extends StatelessWidget {
  const UltramanStarfield({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(),
      size: Size.infinite,
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final math.Random _rng = math.Random(42); // 固定种子保证稳定

  @override
  void paint(Canvas canvas, Size size) {
    // 深空渐变
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1026), Color(0xFF1B2A6B), Color(0xFF0B1026)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // 星点
    for (int i = 0; i < 120; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final r = _rng.nextDouble() * 1.8 + 0.4;
      final opacity = _rng.nextDouble() * 0.7 + 0.3;
      final star = Paint()..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, star);
    }

    // 星云光斑
    for (int i = 0; i < 5; i++) {
      final cx = _rng.nextDouble() * size.width;
      final cy = _rng.nextDouble() * size.height;
      final nebula = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00A0E9).withValues(alpha: 0.25),
            const Color(0xFF00A0E9).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: 120),
        );
      canvas.drawCircle(Offset(cx, cy), 120, nebula);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 怪兽占位图形 (基于 iconName 变化配色与形状，模拟不同怪兽)。
///
/// 根据 [iconName] 的哈希值，组合出差异化的怪兽形象：
/// 不同身体形状（圆/椭圆/三角）、角类型（双角/触须/耳朵/独角）、
/// 眼睛（圆/椭圆/斜眼）、嘴巴（锯齿/獠牙/笑），并搭配不同配色，
/// 让每个任务都有独一无二的怪兽，而非仅颜色不同。
class MonsterAvatar extends StatelessWidget {
  final String iconName;
  final double size;
  const MonsterAvatar({super.key, required this.iconName, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MonsterPainter(iconName),
    );
  }
}

class _MonsterPainter extends CustomPainter {
  final String iconName;
  _MonsterPainter(this.iconName);

  // 基于名字哈希的稳定随机源，保证同一怪兽每次绘制一致。
  int get _h => iconName.hashCode.abs();

  // 配色更丰富 (11 种)，按哈希取。
  Color get _baseColor {
    const palette = [
      Color(0xFF7C4DFF), // 紫
      Color(0xFF26A69A), // 青
      Color(0xFF5C6BC0), // 靛蓝
      Color(0xFF0097A7), // 蓝绿
      Color(0xFF7E57C2), // 深紫
      Color(0xFFEF6C00), // 橙
      Color(0xFF43A047), // 绿
      Color(0xFFE53935), // 红
      Color(0xFF00897B), // 深青
      Color(0xFF8E24AA), // 紫红
      Color(0xFF3949AB), // 靛
    ];
    return palette[_h % palette.length];
  }

  Color get _bellyColor => Color.lerp(_baseColor, Colors.white, 0.55)!;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bodyShape = _h % 3; // 0=圆 1=椭圆 2=三角
    final hornType = (_h ~/ 3) % 4; // 0=双角 1=触须 2=耳朵 3=独角
    final eyeType = (_h ~/ 12) % 3; // 0=圆眼 1=椭圆眼 2=斜眼
    final mouthType = (_h ~/ 36) % 3; // 0=锯齿 1=獠牙 2=笑

    // ===== 身体 =====
    final body = Paint()..color = _baseColor;
    switch (bodyShape) {
      case 1: // 椭圆
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 1.8,
            height: radius * 1.5,
          ),
          body,
        );
        break;
      case 2: // 三角（怪兽头部更尖锐）
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 1.3)
          ..lineTo(center.dx + radius * 1.15, center.dy + radius * 1.1)
          ..lineTo(center.dx - radius * 1.15, center.dy + radius * 1.1)
          ..close();
        canvas.drawPath(path, body);
        break;
      default: // 圆
        canvas.drawCircle(center, radius * 0.9, body);
    }

    // ===== 肚子（浅色圆形） =====
    final belly = Paint()..color = _bellyColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.35),
        width: radius * 0.9,
        height: radius * 0.7,
      ),
      belly,
    );

    // ===== 角 / 触须 / 耳朵 =====
    _drawHorns(canvas, center, radius, hornType);

    // ===== 眼睛 =====
    _drawEyes(canvas, center, radius, eyeType);

    // ===== 嘴巴 =====
    _drawMouth(canvas, center, radius, mouthType);
  }

  void _drawHorns(Canvas canvas, Offset center, double radius, int hornType) {
    final horn = Paint()..color = _baseColor;
    final hornDark = Paint()..color = Color.lerp(_baseColor, Colors.black, 0.25)!;

    switch (hornType) {
      case 1: // 触须（顶部两根弯曲线 + 圆球）
        final tentacle = Paint()
          ..color = _baseColor
          ..strokeWidth = radius * 0.12
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        for (final side in [-1.0, 1.0]) {
          final start = Offset(center.dx + side * radius * 0.4, center.dy - radius * 0.6);
          final end = Offset(center.dx + side * radius * 0.9, center.dy - radius * 1.1);
          canvas.drawLine(start, end, tentacle);
          canvas.drawCircle(end, radius * 0.14, horn);
        }
        break;
      case 2: // 耳朵（顶部两个三角）
        for (final side in [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(center.dx + side * radius * 0.25, center.dy - radius * 0.6)
            ..lineTo(center.dx + side * radius * 0.75, center.dy - radius * 1.2)
            ..lineTo(center.dx + side * radius * 0.85, center.dy - radius * 0.4)
            ..close();
          canvas.drawPath(path, horn);
        }
        break;
      case 3: // 独角（顶部中间单角）
        final path = Path()
          ..moveTo(center.dx - radius * 0.2, center.dy - radius * 0.6)
          ..lineTo(center.dx, center.dy - radius * 1.35)
          ..lineTo(center.dx + radius * 0.2, center.dy - radius * 0.6)
          ..close();
        canvas.drawPath(path, hornDark);
        break;
      default: // 双角
        for (final side in [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(center.dx + side * radius * 0.35, center.dy - radius * 0.65)
            ..lineTo(center.dx + side * radius * 0.7, center.dy - radius * 1.15)
            ..lineTo(center.dx + side * radius * 0.15, center.dy - radius * 0.85)
            ..close();
          canvas.drawPath(path, hornDark);
        }
    }
  }

  void _drawEyes(Canvas canvas, Offset center, double radius, int eyeType) {
    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFFFFC107);

    switch (eyeType) {
      case 1: // 椭圆眼（横长）
        for (final side in [-1.0, 1.0]) {
          final eyeCenter = Offset(center.dx + side * radius * 0.32, center.dy - radius * 0.15);
          final rect = Rect.fromCenter(
            center: eyeCenter,
            width: radius * 0.55,
            height: radius * 0.3,
          );
          canvas.drawOval(rect, eyeWhite);
          canvas.drawOval(
            Rect.fromCenter(
              center: eyeCenter,
              width: radius * 0.24,
              height: radius * 0.3,
            ),
            pupil,
          );
        }
        break;
      case 2: // 斜眼（怒目）
        for (final side in [-1.0, 1.0]) {
          final eyeCenter = Offset(center.dx + side * radius * 0.32, center.dy - radius * 0.15);
          final eyePaint = Paint()
            ..color = Colors.white
            ..strokeWidth = radius * 0.14
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(eyeCenter.dx - radius * 0.2, eyeCenter.dy + radius * 0.1),
            Offset(eyeCenter.dx + radius * 0.2, eyeCenter.dy - radius * 0.1),
            eyePaint,
          );
        }
        break;
      default: // 圆眼
        for (final side in [-1.0, 1.0]) {
          final eyeCenter = Offset(center.dx + side * radius * 0.32, center.dy - radius * 0.15);
          canvas.drawCircle(eyeCenter, radius * 0.2, eyeWhite);
          canvas.drawCircle(eyeCenter, radius * 0.1, pupil);
        }
        break;
    }
  }

  void _drawMouth(Canvas canvas, Offset center, double radius, int mouthType) {
    final mouthY = center.dy + radius * 0.28;

    switch (mouthType) {
      case 1: // 獠牙（两颗尖牙）
        final fang = Paint()..color = Colors.white;
        for (final side in [-1.0, 1.0]) {
          final path = Path()
            ..moveTo(center.dx + side * radius * 0.3, mouthY)
            ..lineTo(center.dx + side * radius * 0.18, mouthY + radius * 0.32)
            ..lineTo(center.dx + side * radius * 0.06, mouthY)
            ..close();
          canvas.drawPath(path, fang);
        }
        break;
      case 2: // 笑（弯月）
        final smile = Paint()
          ..color = Colors.white
          ..strokeWidth = radius * 0.08
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(center.dx, mouthY), width: radius * 0.7, height: radius * 0.4),
          0.15,
          3.14 - 0.3,
          false,
          smile,
        );
        break;
      default: // 锯齿嘴
        final mouth = Paint()
          ..color = Colors.white
          ..strokeWidth = radius * 0.07
          ..style = PaintingStyle.stroke;
        final path = Path();
        path.moveTo(center.dx - radius * 0.38, mouthY);
        for (int i = 0; i <= 4; i++) {
          final x = center.dx - radius * 0.38 + (radius * 0.76) * i / 4;
          final y = mouthY + (i.isEven ? -radius * 0.12 : radius * 0.12);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, mouth);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MonsterPainter oldDelegate) =>
      oldDelegate.iconName != iconName;
}

/// 光之巨人头像 (奥特曼风格)。
///
/// 优先加载英雄专属立绘 [hero.imageAsset] (真实素材)，缺失时回退到
/// 程序绘制：根据 [hero.colorHex] 与 [hero.id] 生成差异化配色/特征的
/// 光之巨人剪影，让每个英雄都有独特外观。
class UltramanHeroAvatar extends StatelessWidget {
  final double size;
  final HeroEntry? hero;

  const UltramanHeroAvatar({super.key, this.size = 60, this.hero});

  @override
  Widget build(BuildContext context) {
    final imageAsset = hero?.imageAsset ?? '';
    if (imageAsset.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          imageAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          // 真实素材缺失时回退到程序绘制
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            size: Size.square(size),
            painter: _HeroPainter(hero),
          ),
        ),
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _HeroPainter(hero),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final HeroEntry? hero;
  _HeroPainter(this.hero);

  // 主体配色：以英雄 colorHex 为基准，银灰打底
  Color get _accent {
    if (hero != null && hero!.colorHex.isNotEmpty) {
      return Color(int.parse('FF${hero!.colorHex}', radix: 16));
    }
    return const Color(0xFF5C6BC0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final accent = _accent;

    // 银色头盔主体 (圆润的头部，带柔和渐变)
    final head = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE8EAF6),
          Color.lerp(accent, const Color(0xFFC0C0C0), 0.55)!,
          const Color(0xFFC0C0C0),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: r * 1.3,
          height: r * 1.6,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.2, height: r * 1.5),
      head,
    );

    // 头部正中「光之棱镜」装饰 (英雄主色 + 计时器蓝)
    final prism = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent, const Color(0xFF00A0E9)],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: r * 0.34,
          height: r * 1.3,
        ),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: r * 0.34,
          height: r * 1.3,
        ),
        Radius.circular(r * 0.17),
      ),
      prism,
    );

    // 计时器蓝眼睛 (两侧斜向发光眼)
    final eyeGlow = Paint()..color = const Color(0xFF00A0E9).withValues(alpha: 0.35);
    final eye = Paint()..color = const Color(0xFF00A0E9);
    for (final side in [-1.0, 1.0]) {
      final eyeRect = Rect.fromCenter(
        center: Offset(center.dx + side * r * 0.42, center.dy - r * 0.12),
        width: r * 0.5,
        height: r * 0.24,
      );
      canvas.drawOval(eyeRect.inflate(r * 0.12), eyeGlow);
      canvas.drawOval(eyeRect, eye);
    }

    // 计时器 (胸口能量灯)
    final timerGlow = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.4);
    final timer = Paint()..color = const Color(0xFFFFC107);
    canvas.drawCircle(Offset(center.dx, center.dy + r * 0.5), r * 0.34, timerGlow);
    canvas.drawCircle(Offset(center.dx, center.dy + r * 0.5), r * 0.24, timer);

    // 银色描边 (勾勒轮廓)
    final outline = Paint()
      ..color = const Color(0xFF7986CB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.2, height: r * 1.5),
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) =>
      oldDelegate.hero?.id != hero?.id;
}

/// 光线攻击全屏特效 (动画覆盖层)。
///
/// 优先尝试播放当前英雄专属技能动画 [hero.skillAnimAsset]，
/// 其次回退到通用 beam_attack.json，再回退到纯代码绘制特效，
/// 保证无论是否配置动画资源，打卡体验都不断档。
class BeamAttackEffect extends StatefulWidget {
  final HeroEntry? hero;
  const BeamAttackEffect({super.key, this.hero});

  @override
  State<BeamAttackEffect> createState() => _BeamAttackEffectState();
}

class _BeamAttackEffectState extends State<BeamAttackEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _lottieFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 资源加载失败后回退到代码绘制
    if (_lottieFailed) {
      return _FallbackBeamEffect(controller: _controller, hero: widget.hero);
    }

    final heroAnim = widget.hero?.skillAnimAsset ?? '';
    final animAsset = heroAnim.isNotEmpty ? heroAnim : 'assets/lottie/beam_attack.json';

    // 优先 Lottie 动画
    return Lottie.asset(
      animAsset,
      fit: BoxFit.cover,
      onLoaded: (_) {},
      errorBuilder: (context, error, stackTrace) {
        // 资源不存在或解析失败：切换到回退特效
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _lottieFailed = true);
        });
        return _FallbackBeamEffect(controller: _controller, hero: widget.hero);
      },
    );
  }
}

/// 纯代码绘制的光线攻击特效 (无资源时的兜底)。
class _FallbackBeamEffect extends StatelessWidget {
  final AnimationController controller;
  final HeroEntry? hero;
  const _FallbackBeamEffect({required this.controller, this.hero});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return CustomPaint(
          size: Size.infinite,
          painter: _BeamPainter(t, hero?.colorHex),
        );
      },
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double t;
  final String? colorHex;
  _BeamPainter(this.t, this.colorHex);

  Color get _accent {
    if (colorHex != null && colorHex!.isNotEmpty) {
      return Color(int.parse('FF$colorHex', radix: 16));
    }
    return const Color(0xFF00A0E9);
  }

  // 固定种子保证粒子分布稳定，避免每帧抖动
  final math.Random _rng = math.Random(2024);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = size.shortestSide;

    // 半透明遮罩 (随时间淡出)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.55 * (1 - t)),
    );

    // 阶段：0.0~0.35 蓄力汇聚，0.35~0.8 释放冲击，0.8~1.0 余晖消散
    final chargePhase = t < 0.35;
    final chargeP = (t / 0.35).clamp(0.0, 1.0); // 蓄力进度
    final burstP = ((t - 0.35) / 0.45).clamp(0.0, 1.0); // 释放进度
    final fadeP = ((t - 0.8) / 0.2).clamp(0.0, 1.0); // 余晖消散

    // ===== 1) 蓄力阶段：核心能量汇聚光球 (从中心向外膨胀) =====
    if (chargePhase) {
      final coreR = shortest * 0.05 + shortest * 0.22 * chargeP;
      // 能量汇聚光环 (多层同心圆，形成蓄力感)
      for (int ring = 0; ring < 3; ring++) {
        final rr = coreR * (0.6 + ring * 0.3);
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + (2 - ring) * 1.0
          ..color = _accent.withValues(alpha: 0.5 * chargeP * (1 - ring * 0.25));
        canvas.drawCircle(center, rr, ringPaint);
      }
      // 核心光球 (英雄色 -> 白 -> 金 三层渐变)
      final coreGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * chargeP),
            _accent.withValues(alpha: 0.75 * chargeP),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR * 2.2));
      canvas.drawCircle(center, coreR * 2.2, coreGlow);

      // 向内汇聚的能量粒子流 (从四周飞向中心)
      _drawChargeParticles(canvas, center, shortest, chargeP);
      return;
    }

    // ===== 2) 释放阶段：爆炸 + 放射光线 + 冲击波 =====
    final radius = shortest * 0.28 * (0.6 + burstP * 0.5) * (1 - fadeP * 0.4);

    // 核心爆炸光球 (白 -> 金 -> 英雄色 -> 透明)
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95 * (1 - fadeP)),
          const Color(0xFFFFC107).withValues(alpha: 0.7 * (1 - fadeP)),
          _accent.withValues(alpha: 0.5 * (1 - fadeP)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6));
    canvas.drawCircle(center, radius * 1.6, glow);

    // 冲击波扩散环 (释放瞬间向外扩散)
    final shockR = shortest * 0.05 + shortest * 0.5 * burstP;
    final shock = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * (1 - burstP) + 1.5
      ..color = Colors.white.withValues(alpha: 0.85 * (1 - burstP) * (1 - fadeP));
    canvas.drawCircle(center, shockR, shock);

    // 第二道冲击波 (英雄色)
    final shock2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - burstP) + 1
      ..color = _accent.withValues(alpha: 0.7 * (1 - burstP) * (1 - fadeP));
    canvas.drawCircle(center, shockR * 0.85, shock2);

    // 放射光线 (更多、更锐利，带英雄色与白色双层)
    final rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final angle = (math.pi * 2 / rayCount) * i + t * 0.4;
      final dir = Offset(math.cos(angle), math.sin(angle));
      // 白色内核光线
      final rayWhite = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * (1 - fadeP))
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final start1 = center + dir * radius * 0.5;
      final end1 = center + dir * (radius + shortest * 0.28 * burstP);
      canvas.drawLine(start1, end1, rayWhite);
      // 英雄色外发光光线 (更粗更长)
      final rayAccent = Paint()
        ..color = _accent.withValues(alpha: 0.55 * (1 - fadeP))
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final start2 = center + dir * radius * 0.4;
      final end2 = center + dir * (radius + shortest * 0.4 * burstP);
      canvas.drawLine(start2, end2, rayAccent);
    }

    // 飞散的能量粒子 (从爆炸中心向外飞散，模拟光尘)
    _drawBurstParticles(canvas, center, shortest, burstP, fadeP);

    // 余晖：中心光点渐渐收拢
    if (fadeP > 0) {
      final afterglow = Paint()
        ..shader = RadialGradient(
          colors: [
            _accent.withValues(alpha: 0.6 * (1 - fadeP)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: shortest * 0.2));
      canvas.drawCircle(center, shortest * 0.2, afterglow);
    }
  }

  /// 蓄力阶段：能量粒子从四周向中心汇聚。
  void _drawChargeParticles(Canvas canvas, Offset center, double shortest, double chargeP) {
    const particleCount = 36;
    final maxR = shortest * 0.42;
    for (int i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i + _rng.nextDouble() * 0.3;
      // 粒子从外向内移动
      final dist = maxR * (1 - chargeP) + shortest * 0.02;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final size = 2.5 * chargeP + 1;
      final particle = Paint()
        ..color = (i.isEven ? Colors.white : _accent)
            .withValues(alpha: 0.8 * chargeP);
      canvas.drawCircle(p, size, particle);
    }
  }

  /// 释放阶段：能量粒子从爆炸中心向外飞散。
  void _drawBurstParticles(
    Canvas canvas,
    Offset center,
    double shortest,
    double burstP,
    double fadeP,
  ) {
    const particleCount = 28;
    for (int i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i + _rng.nextDouble() * 0.5;
      final dist = shortest * 0.1 + shortest * 0.45 * burstP;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final size = (4.5 * (1 - burstP) + 1) * (1 - fadeP * 0.7);
      final particle = Paint()
        ..color = (i % 3 == 0 ? const Color(0xFFFFC107) : _accent)
            .withValues(alpha: 0.8 * (1 - burstP) * (1 - fadeP));
      canvas.drawCircle(p, size, particle);
    }
  }

  @override
  bool shouldRepaint(covariant _BeamPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colorHex != colorHex;
}

/// 胜利特效 (动画覆盖层)。
///
/// 优先播放 Lottie 胜利动画 (assets/lottie/victory.json)，
/// 资源缺失时回退到 [BeamAttackEffect] 兜底，保证不断档。
class VictoryEffect extends StatefulWidget {
  final HeroEntry? hero;
  const VictoryEffect({super.key, this.hero});

  @override
  State<VictoryEffect> createState() => _VictoryEffectState();
}

class _VictoryEffectState extends State<VictoryEffect> {
  bool _lottieFailed = false;

  @override
  Widget build(BuildContext context) {
    if (_lottieFailed) {
      return BeamAttackEffect(hero: widget.hero);
    }
    return Lottie.asset(
      'assets/lottie/victory.json',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _lottieFailed = true);
        });
        return BeamAttackEffect(hero: widget.hero);
      },
    );
  }
}

/// 庆祝奖励动画 (全屏覆盖层)。
///
/// 纯代码绘制的庆祝特效，用于儿童完成数学题/打卡达标后的奖励反馈：
/// 居中的奖杯 + 金色光环扩散 + 彩色烟花粒子 + 飘落彩带 + 庆祝文字。
/// 不依赖任何外部资源，保证稳定展示且始终居中。
class CelebrationEffect extends StatefulWidget {
  final String title; // 庆祝主文字 (如「真棒」)
  final String subtitle; // 副文字 (如「获得奖励」)
  final VoidCallback? onCompleted; // 动画播放完毕回调 (用于关闭覆盖层)
  const CelebrationEffect({
    super.key,
    this.title = '真棒！',
    this.subtitle = '',
    this.onCompleted,
  });

  @override
  State<CelebrationEffect> createState() => _CelebrationEffectState();
}

class _CelebrationEffectState extends State<CelebrationEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return CustomPaint(
          size: Size.infinite,
          painter: _CelebrationPainter(
            t: t,
            title: widget.title,
            subtitle: widget.subtitle,
          ),
        );
      },
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  final double t;
  final String title;
  final String subtitle;
  final math.Random _rng = math.Random(88); // 固定种子，粒子稳定

  _CelebrationPainter({
    required this.t,
    required this.title,
    required this.subtitle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = size.shortestSide;

    // 半透明深色遮罩 (随时间略淡)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.35 * (1 - t * 0.3)),
    );

    // ===== 1) 金色光环扩散 (从中心向外) =====
    for (int ring = 0; ring < 4; ring++) {
      final ringT = ((t * 1.2) - ring * 0.18).clamp(0.0, 1.0);
      if (ringT <= 0) continue;
      final radius = shortest * 0.12 + shortest * 0.5 * ringT;
      final alpha = (1 - ringT) * 0.7;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + ring * 1.0
        ..color = (ring.isEven
                ? const Color(0xFFFFC107)
                : const Color(0xFFFFE082))
            .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }

    // ===== 2) 中心光晕 (暖金渐变) =====
    final glowRadius = shortest * 0.24 * (0.7 + 0.3 * _easeOut(t));
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5 * (1 - t * 0.4)),
          const Color(0xFFFFC107).withValues(alpha: 0.35 * (1 - t * 0.3)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glow);

    // ===== 3) 居中奖杯 (缩放弹出) =====
    final scale = _easeOutBack((t / 0.4).clamp(0.0, 1.0));
    _drawTrophy(canvas, center, shortest * 0.22 * scale);

    // ===== 4) 彩色烟花粒子 (从中心向外飞散) =====
    _drawFireworks(canvas, center, shortest);

    // ===== 5) 飘落彩带 (从顶部飘下) =====
    _drawConfetti(canvas, size, shortest);

    // ===== 6) 庆祝文字 (居中) =====
    _drawText(canvas, center, shortest);
  }

  /// 奖杯绘制 (金色奖杯 + 底座)。
  void _drawTrophy(Canvas canvas, Offset center, double size) {
    if (size <= 0) return;
    const gold = Color(0xFFFFC107);
    const goldDark = Color(0xFFE6A800);
    const goldLight = Color(0xFFFFE082);

    // 杯身 (梯形)
    final cupPath = Path()
      ..moveTo(center.dx - size * 0.5, center.dy - size * 0.5)
      ..lineTo(center.dx + size * 0.5, center.dy - size * 0.5)
      ..lineTo(center.dx + size * 0.32, center.dy + size * 0.05)
      ..lineTo(center.dx - size * 0.32, center.dy + size * 0.05)
      ..close();
    canvas.drawPath(cupPath, Paint()..color = gold);

    // 杯耳 (左右两个把手)
    final handlePaint = Paint()
      ..color = goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.14;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(center.dx - size * 0.52, center.dy - size * 0.1),
        radius: size * 0.28,
      ),
      math.pi * 0.5,
      math.pi,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(center.dx + size * 0.52, center.dy - size * 0.1),
        radius: size * 0.28,
      ),
      math.pi * 1.5,
      math.pi,
      false,
      handlePaint,
    );

    // 底座
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + size * 0.35),
          width: size * 0.7,
          height: size * 0.2,
        ),
        Radius.circular(size * 0.06),
      ),
      Paint()..color = goldDark,
    );

    // 高光
    canvas.drawCircle(
      Offset(center.dx - size * 0.2, center.dy - size * 0.25),
      size * 0.08,
      Paint()..color = goldLight,
    );
  }

  /// 彩色烟花粒子。
  void _drawFireworks(Canvas canvas, Offset center, double shortest) {
    const colors = [
      Color(0xFFFFC107), // 金
      Color(0xFFFF6B6B), // 红
      Color(0xFF4FC3F7), // 蓝
      Color(0xFF81C784), // 绿
      Color(0xFFBA68C8), // 紫
      Color(0xFFFF8A65), // 橙
    ];
    for (int i = 0; i < 40; i++) {
      final angle = (math.pi * 2 / 40) * i + _rng.nextDouble() * 0.5;
      final speed = 0.8 + _rng.nextDouble() * 0.5;
      final dist = shortest * 0.15 + shortest * 0.55 * t * speed;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final fade = (1 - t).clamp(0.0, 1.0);
      final radius = 2.0 + _rng.nextDouble() * 3.0;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: fade);
      canvas.drawCircle(p, radius, paint);
    }
  }

  /// 飘落彩带 (顶部随机位置飘下)。
  void _drawConfetti(Canvas canvas, Size size, double shortest) {
    const colors = [
      Color(0xFFFFC107),
      Color(0xFFFF6B6B),
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
      Color(0xFFBA68C8),
    ];
    for (int i = 0; i < 30; i++) {
      final x = (_rng.nextDouble() * size.width);
      final speed = 0.6 + _rng.nextDouble() * 0.8;
      final y = -shortest * 0.1 + size.height * t * speed;
      if (y > size.height) continue;
      final rot = _rng.nextDouble() * math.pi;
      final w = 4 + _rng.nextDouble() * 5;
      final h = 6 + _rng.nextDouble() * 6;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  /// 居中庆祝文字。
  void _drawText(Canvas canvas, Offset center, double shortest) {
    final textT = ((t - 0.25) / 0.3).clamp(0.0, 1.0);
    if (textT <= 0) return;

    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: const Color(0xFFFFE082).withValues(alpha: textT),
          fontSize: shortest * 0.1,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        center.dx - tp.width / 2,
        center.dy + shortest * 0.35,
      ),
    );

    if (subtitle.isNotEmpty) {
      final sp = TextPainter(
        text: TextSpan(
          text: subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: textT * 0.9),
            fontSize: shortest * 0.05,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sp.paint(
        canvas,
        Offset(
          center.dx - sp.width / 2,
          center.dy + shortest * 0.35 + tp.height + 6,
        ),
      );
    }
  }

  double _easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();

  double _easeOutBack(double x) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(x - 1, 3).toDouble() + c1 * math.pow(x - 1, 2).toDouble();
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.t != t;
}
