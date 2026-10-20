import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/check_in_record.dart';
import '../../../data/models/task.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 保卫萝卜式「蛇形小路选关」。
///
/// 关卡不再排成直线，而是沿一条弯弯曲曲的蛇形小路铺开：
/// 路径用 Catmull-Rom 样条在随机抖动后的控制点上生成，
/// 关卡节点按弧长均匀摆放在小路上，像铺在蜿蜒小径上的一块块圆石。
///
/// 已打卡关卡高亮 (金色) 并在下方显示打卡日期与时间；
/// 点击任意关卡可查看该次打卡的完整日期时间。
class LevelMap extends ConsumerWidget {
  final Task task;
  final String childId;

  const LevelMap({super.key, required this.task, required this.childId});

  /// 非「打卡一周」任务的默认目标关卡总数。
  static const int defaultLevelCount = 30;

  static int targetCount(Task task) {
    if (task.type == 'checkin_week') return 7;
    return defaultLevelCount;
  }

  // ---- 布局常量 (普通逻辑像素，横向平板不会被放大) ----
  static const double _hMargin = 24; // 左右留白
  static const double _labelHeight = 26; // 节点下方文字区高度

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecords = ref.watch(childCheckInProvider(childId));
    final completed = allRecords
        .where((r) => r.taskId == task.id && r.status == 'completed')
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final Map<String, CheckInRecord> checkInByDate = {};
    for (final r in completed) {
      checkInByDate.putIfAbsent(r.date, () => r);
    }
    final orderedRecords = checkInByDate.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final total = targetCount(task);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 节点直径：随可用宽度自适应，限制上限
        final diameter = (width / _colsForWidth(width) * 0.62).clamp(32.0, 52.0);

        final cols = _colsForWidth(width);
        final rows = (total + cols - 1) ~/ cols;
        const rowGap = 34.0; // 行间距 (容纳拐弯与下方文字)
        final rowH = diameter + rowGap;
        final height = rows * rowH + _labelHeight;

        // 1) 蛇形网格定位 (保证相邻节点水平间距 = cellW，绝不重叠)
        final cellW = (width - _hMargin * 2) / cols;
        final rng = math.Random(7); // 固定种子，布局稳定不抖动

        Offset centerOf(int level) {
          final idx = level - 1;
          final row = idx ~/ cols;
          final colInRow = idx % cols;
          // 偶数行从左到右，奇数行从右到左 (蛇形来回绕)
          final visualCol = row.isEven ? colInRow : cols - 1 - colInRow;
          final x = _hMargin + cellW * (visualCol + 0.5);
          // y 基准 + 小幅随机抖动 (±12px)，让路看起来弯弯曲曲
          final baseY = row * rowH + diameter / 2;
          final wiggle = (rng.nextDouble() - 0.5) * 24;
          final y = baseY + wiggle.clamp(-rowGap / 2 + 6, rowGap / 2 - 6);
          return Offset(x, y);
        }

        // 2) 节点中心序列 -> 平滑小路穿过所有关卡
        final nodeCenters = [
          for (int i = 1; i <= total; i++) centerOf(i),
        ];
        final path = _catmullRomPath(nodeCenters);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _buildProgressHeader(orderedRecords, total),
            const SizedBox(height: 12),
            SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 底层：弯曲蛇形小路 (带状路径)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WindingRoadPainter(
                        path: path,
                        width: diameter + 12,
                      ),
                    ),
                  ),
                  // 上层：关卡节点 (圆石)；首个未打卡关为「当前关」蓝色高亮
                  for (int i = 0; i < total; i++)
                    Positioned(
                      left: nodeCenters[i].dx - diameter / 2,
                      top: nodeCenters[i].dy - diameter / 2,
                      child: _buildNode(
                        context,
                        i + 1,
                        i < orderedRecords.length
                            ? orderedRecords[i]
                            : null,
                        diameter,
                        isCurrent: i == orderedRecords.length,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  int _colsForWidth(double width) {
    if (width >= 700) return 10;
    if (width >= 520) return 8;
    if (width >= 380) return 6;
    return 5;
  }

  /// Catmull-Rom 样条 → 贝塞尔 Path (经过所有控制点的平滑曲线)。
  Path _catmullRomPath(List<Offset> pts) {
    final path = Path();
    if (pts.length < 2) return path;
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 < pts.length ? i + 2 : pts.length - 1];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// 顶部进度说明：已通关 x / total 关。
  Widget _buildProgressHeader(List<CheckInRecord> orderedRecords, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hMargin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.map, color: UltramanTheme.gold, size: 18),
            const SizedBox(width: 6),
            Text(
              '已通关 ${orderedRecords.length} / $total 关',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个关卡节点 (铺在路上的圆石)。
  Widget _buildNode(
    BuildContext context,
    int levelNumber,
    CheckInRecord? record,
    double diameter, {
    bool isCurrent = false,
  }) {
    final isDone = record != null;

    return InkWell(
      onTap: () => _showLevelDetail(context, levelNumber, record),
      borderRadius: BorderRadius.circular(100),
      child: SizedBox(
        width: diameter,
        height: diameter + _labelHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? UltramanTheme.gold
                    : Colors.white.withValues(alpha: 0.14),
                border: Border.all(
                  color: isDone
                      ? Colors.white
                      : isCurrent
                          ? UltramanTheme.blue
                          : Colors.white.withValues(alpha: 0.28),
                  width: isDone ? 2 : (isCurrent ? 2.5 : 1.5),
                ),
                boxShadow: isDone
                    ? [
                        BoxShadow(
                          color: UltramanTheme.gold.withValues(alpha: 0.55),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : isCurrent
                        ? [
                            BoxShadow(
                              color: UltramanTheme.blue.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
              ),
              alignment: Alignment.center,
              child: isDone
                  ? Icon(Icons.check,
                      color: Colors.white, size: diameter * 0.5)
                  : Text(
                      '$levelNumber',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: diameter * 0.4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            // 下方文字区：仅已打卡显示日期+时间，未打卡留空
            SizedBox(
              height: _labelHeight,
              child: isDone
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shortDate(record.date),
                          style: const TextStyle(
                            color: UltramanTheme.gold,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _shortTime(record.createdAt),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// 图例说明。
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(UltramanTheme.gold, '已打卡'),
        const SizedBox(width: 16),
        _legendDot(Colors.white.withValues(alpha: 0.3), '未打卡'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  /// 点击关卡弹出详情：显示打卡的具体日期时间。
  void _showLevelDetail(
    BuildContext context,
    int levelNumber,
    CheckInRecord? record,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1B2A6B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: record != null
                    ? UltramanTheme.gold
                    : Colors.white.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Text(
                '$levelNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '第 $levelNumber 关',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (record != null) ...[
              const Text(
                '已通关',
                style: TextStyle(color: UltramanTheme.gold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                '打卡日期：${record.date}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '打卡时间：${_fullTime(record.createdAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ] else
              const Text(
                '尚未打卡',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length >= 3) return '${parts[1]}-${parts[2]}';
    return date;
  }

  String _shortTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fullTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// 弯弯曲曲的蛇形小路画笔：沿路径画一条圆头带状小路，
/// 带内深外浅的两层描边，模拟土路/石子路的质感。
class _WindingRoadPainter extends CustomPainter {
  final Path path;
  final double width;

  _WindingRoadPainter({required this.path, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    // 外层 (小路边缘)
    final outer = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outer);

    // 内层 (路面主体，半透明白形成路的立体感)
    final inner = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.66
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, inner);

    // 路中央虚线 (行进方向指引)
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      const dashLen = 7.0;
      const gapLen = 7.0;
      double d = 0;
      while (d < m.length) {
        final end = math.min(d + dashLen, m.length);
        canvas.drawPath(m.extractPath(d, end), dash);
        d += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindingRoadPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.width != width;
}
