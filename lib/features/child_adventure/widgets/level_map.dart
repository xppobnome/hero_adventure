import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/check_in_record.dart';
import '../../../data/models/task.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 打卡日历视图。
///
/// 根据任务周期类型，以「日历」形式展示打卡情况，日期格子为正方形：
/// - 每日任务 (`daily`/`math`)：展示当月，目标 = 当月天数。
/// - 每周任务 (`weekly`)：整月显示，本周日期加强调色。
/// - 打卡一周 / 连续30天 (`checkin_week`/`checkin_month`)：从设置那天起，
///   连续 7 / 30 天，作为日历窗口展示。
/// - 打卡指定星期 (`custom_days`)：展示当月，目标 = 当月内选中星期的天数。
/// - 自定义周期 (`custom_range`)：不展示月份，直接展示起止日期区间日历。
/// - 单次任务 (`once`)：展示当月，完成日高亮。
///
/// 视觉：底部浅色大月份文字 + 半透明日期网格 + 顶部星期标注，
/// 已打卡日期格子下方只显示打卡时间 (不显示日期)。
class LevelMap extends ConsumerWidget {
  final Task task;
  final String childId;

  const LevelMap({super.key, required this.task, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecords = ref.watch(childCheckInProvider(childId));
    final completed = allRecords
        .where((r) => r.taskId == task.id && r.status == 'completed')
        .toList();

    // 横屏检测：平板/手机横屏时日历更紧凑，避免内容过高需要滚动。
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    // 按日期索引打卡记录 (同日多条取最新一条)。
    final Map<String, CheckInRecord> recordByDate = {};
    for (final r in completed) {
      final existing = recordByDate[r.date];
      if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
        recordByDate[r.date] = r;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ===== 确定展示区间 [displayStart, displayEnd] =====
    final DateTime displayStart;
    final DateTime displayEnd;
    final bool isRangeMode; // 是否按「周期区间」展示（非整月）

    if (task.type == 'custom_range' &&
        task.rangeStart.isNotEmpty &&
        task.rangeEnd.isNotEmpty) {
      displayStart = DateTime.tryParse(task.rangeStart) ?? today;
      displayEnd = DateTime.tryParse(task.rangeEnd) ?? today;
      isRangeMode = true;
    } else if ((task.type == 'checkin_week' || task.type == 'checkin_month') &&
        task.rangeStart.isNotEmpty &&
        task.rangeEnd.isNotEmpty) {
      displayStart = DateTime.tryParse(task.rangeStart) ?? today;
      displayEnd = DateTime.tryParse(task.rangeEnd) ?? today;
      isRangeMode = true;
    } else {
      displayStart = DateTime(today.year, today.month, 1);
      displayEnd = DateTime(today.year, today.month + 1, 0); // 月末
      isRangeMode = false;
    }

    // ===== 动态计算目标天数 =====
    final targetDays = _targetDays(task, displayStart, displayEnd);

    // ===== 判定某日期是否「需要打卡 / 待打卡」（强调色） =====
    //
    // 规则：
    // - weekly (每周特训)：整周 (周一~周日) 都高亮，表示「本周任务周期」，
    //   本周任意一天打卡一次即可完成，因此不受「过去日期」限制。
    // - 其他类型：高亮 = 属于任务区间（任务日） 且 不早于今天（今天或未来）。
    //   已过去的未打卡日期视为「错过」，不再高亮；已打卡的过去日期由金色兜底。
    bool isEmphasized(DateTime d) {
      switch (task.type) {
        case 'weekly':
          // 每周任务：整周 (周一~周日) 都高亮可选。
          final monday = today.subtract(Duration(days: today.weekday - 1));
          final sunday = monday.add(const Duration(days: 6));
          return !d.isBefore(monday) && !d.isAfter(sunday);
        case 'custom_days':
          // 过去日期不高亮（错过的选中星期不再提示）。
          if (d.isBefore(today)) return false;
          return task.selectedDays.contains(d.weekday);
        case 'custom_range':
        case 'checkin_week':
        case 'checkin_month':
          if (d.isBefore(today)) return false;
          return !d.isBefore(displayStart) && !d.isAfter(displayEnd);
        case 'once':
          // 单次任务：完成前，今天及未来可打卡。
          if (d.isBefore(today)) return false;
          return true;
        default: // daily / math：每天都需打卡，今天及未来高亮
          if (d.isBefore(today)) return false;
          return true;
      }
    }

    // ===== 生成日期格子数据 =====
    final cells = _buildCells(displayStart, displayEnd);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 16,
        vertical: isLandscape ? 6 : 12,
      ),
      child: Column(
        children: [
          _buildHeader(recordByDate.length, targetDays),
          SizedBox(height: isLandscape ? 6 : 12),
          _buildCalendar(
            cells: cells,
            monthLabel: _monthLabel(displayStart, displayEnd, isRangeMode),
            recordOf: (d) => recordByDate[_dateKey(d)],
            isEmphasized: isEmphasized,
            isLandscape: isLandscape,
          ),
          SizedBox(height: isLandscape ? 6 : 12),
          _buildLegend(),
        ],
      ),
    );
  }

  /// 动态计算目标天数。
  int _targetDays(Task task, DateTime start, DateTime end) {
    switch (task.type) {
      case 'custom_range':
        return end.difference(start).inDays + 1;
      case 'checkin_week':
        return 7;
      case 'checkin_month':
        return 30;
      case 'weekly':
        // 每周特训：每周只需打卡一次。
        return 1;
      case 'custom_days':
        // 当月内选中星期几出现的天数
        var count = 0;
        var d = start;
        while (!d.isAfter(end)) {
          if (task.selectedDays.contains(d.weekday)) count++;
          d = d.add(const Duration(days: 1));
        }
        return count;
      case 'once':
        return 1;
      default: // daily / math
        return end.difference(start).inDays + 1;
    }
  }

  /// 生成日期格子列表 (含前置空白，使首日对齐星期)。
  List<DateTime?> _buildCells(DateTime start, DateTime end) {
    final cells = <DateTime?>[];
    // 前置空白：首日是周几 (1=周一 ... 7=周日)，表头「日一...六」下标 0=周日。
    final leading = start.weekday % 7; // 周日=7 -> 0, 周一=1 -> 1
    for (int i = 0; i < leading; i++) {
      cells.add(null);
    }
    var d = start;
    while (!d.isAfter(end)) {
      cells.add(d);
      d = d.add(const Duration(days: 1));
    }
    return cells;
  }

  /// 月份标签：整月显示「X月」，区间显示「起始 ~ 结束」。
  String _monthLabel(DateTime start, DateTime end, bool isRangeMode) {
    const monthNames = [
      '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月',
    ];
    if (isRangeMode) {
      return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
    }
    return monthNames[start.month - 1];
  }

  /// 顶部进度说明。
  Widget _buildHeader(int doneCount, int targetDays) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: UltramanTheme.gold, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '已打卡 $doneCount 天 · 目标 $targetDays 天 · ${task.cycleDescription}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (task.requirePhoto) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera, size: 12, color: Colors.orange),
                  SizedBox(width: 2),
                  Text(
                    '需拍照审核',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 日历主体：底部大月份浅色 + 半透明日期网格 + 顶部星期标注。
  Widget _buildCalendar({
    required List<DateTime?> cells,
    required String monthLabel,
    required CheckInRecord? Function(DateTime) recordOf,
    required bool Function(DateTime) isEmphasized,
    required bool isLandscape,
  }) {
    const weekHeader = ['日', '一', '二', '三', '四', '五', '六'];

    return Stack(
      children: [
        // 底部大月份浅色文字
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isLandscape ? 40 : 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
        ),
        // 上半透明日历
        Column(
          children: [
            // 星期表头
            Row(
              children: [
                for (final w in weekHeader)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: isLandscape ? 3 : 6),
                        child: Text(
                          w,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: isLandscape ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // 日期网格 (横屏用更矮的格子，避免整月日历过高需滚动)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                // 横屏：格子更矮（拉长加宽），压缩整月日历高度，尽量不滚动展示完全。
                childAspectRatio: isLandscape ? 1.9 : 1.0,
                mainAxisSpacing: isLandscape ? 2 : 6,
                crossAxisSpacing: isLandscape ? 2 : 4,
              ),
              itemCount: cells.length,
              itemBuilder: (context, index) {
                final d = cells[index];
                if (d == null) {
                  return const SizedBox.shrink(); // 前置空白
                }
                final record = recordOf(d);
                final emphasized = isEmphasized(d);
                return _buildDayCell(
                  day: d.day,
                  record: record,
                  emphasized: emphasized,
                  isLandscape: isLandscape,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 单个日期格子 (横屏时更紧凑)。
  Widget _buildDayCell({
    required int day,
    required CheckInRecord? record,
    required bool emphasized,
    required bool isLandscape,
  }) {
    final isDone = record != null;

    // 背景色：已打卡金色；任务日 (今天/未来需打卡) 半透明白高亮；其余更淡。
    Color bg;
    Color borderColor;
    if (isDone) {
      bg = UltramanTheme.gold;
      borderColor = Colors.white;
    } else if (emphasized) {
      bg = Colors.white.withValues(alpha: 0.16);
      borderColor = UltramanTheme.blue.withValues(alpha: 0.7);
    } else {
      bg = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white.withValues(alpha: 0.12);
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isLandscape ? 4 : 6),
        border: Border.all(color: borderColor, width: isDone ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: isDone
                  ? Colors.white
                  : emphasized
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
              fontSize: isLandscape ? 11 : 14,
              fontWeight: isDone || emphasized ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          SizedBox(height: isLandscape ? 1 : 2),
          // 日期下方：已打卡显示时间；任务日 (含未来) 显示小圆点；其余留白。
          if (isDone)
            Text(
              _shortTime(record!.createdAt),
              style: TextStyle(
                color: Colors.white,
                fontSize: isLandscape ? 7 : 9,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (emphasized)
            Container(
              width: isLandscape ? 3 : 5,
              height: isLandscape ? 3 : 5,
              decoration: const BoxDecoration(
                color: UltramanTheme.blue,
                shape: BoxShape.circle,
              ),
            )
          else
            SizedBox(height: isLandscape ? 6 : 9),
        ],
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
        _legendDot(UltramanTheme.blue, '任务日'),
        const SizedBox(width: 16),
        _legendDot(Colors.white.withValues(alpha: 0.2), '非任务日'),
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

  String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _shortTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
