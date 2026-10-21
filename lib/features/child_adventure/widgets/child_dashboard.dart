import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/stats_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 儿童看板：累计打卡、本周打卡、当前等级、能量币。
///
/// 精简紧凑版：缩小约 50% 高度，横向平板下也不占过多空间，
/// 保证下方内容区始终有足够高度可滚动。
class ChildDashboard extends ConsumerWidget {
  final String childId;
  const ChildDashboard({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(childStatsProvider(childId));

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UltramanTheme.deepSpace, UltramanTheme.nebula],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：等级 + 能量币
            Row(
              children: [
                _statItem(
                  icon: Icons.star,
                  color: UltramanTheme.gold,
                  label: '当前等级',
                  value: 'LV.${stats.level}',
                  footer: stats.expToNext > 0
                      ? '距离升级还有 ${stats.expToNext} EXP'
                      : '已满级',
                ),
                const SizedBox(width: 12),
                _statItem(
                  icon: Icons.bolt,
                  color: UltramanTheme.blue,
                  label: '能量币',
                  value: '${stats.coins}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 等级进度条
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: stats.levelProgress,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(UltramanTheme.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(stats.levelProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 第二行：累计打卡 + 本周打卡
            Row(
              children: [
                _statItem(
                  icon: Icons.flag,
                  color: UltramanTheme.gold,
                  label: '累计打卡',
                  value: '${stats.totalCheckIns}',
                ),
                const SizedBox(width: 12),
                _statItem(
                  icon: Icons.calendar_today,
                  color: Colors.greenAccent,
                  label: '本周打卡',
                  value: '${stats.weekCheckIns}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? footer,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            if (footer != null) ...[
              const SizedBox(height: 2),
              Text(
                footer,
                style: TextStyle(
                  color: UltramanTheme.gold.withValues(alpha: 0.9),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
