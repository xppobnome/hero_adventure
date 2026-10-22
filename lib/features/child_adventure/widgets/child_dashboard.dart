import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/stats_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../../../domain/hero_system.dart' show maxLevel;

/// 儿童看板：累计打卡、本周打卡、当前等级、能量币。
///
/// 等级 + 能量币合并为一个「能量方块」展示（含能量币文字、距升级 EXP），
/// 累计/本周打卡为两个小项。平板横屏下能量方块拉长加宽，充分利用横向
/// 空间，保证下方内容区（日历/任务）有足够空间，尽量不滚动即可展示完全。
class ChildDashboard extends ConsumerWidget {
  final String childId;
  const ChildDashboard({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(childStatsProvider(childId));
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    // 平板横屏：能量方块更宽（flex 更大），但整体 maxWidth 与下方任务列表
    // 保持一致（720），避免横屏下看板与内容区宽度错位。
    final energyFlex = isLandscape ? 5 : 3;
    const double maxWidth = 720.0;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [UltramanTheme.deepSpace, UltramanTheme.nebula],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ===== 能量方块：等级 + 能量币 合并 =====
            Expanded(
              flex: energyFlex,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: UltramanTheme.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: UltramanTheme.gold, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'LV.${stats.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.bolt, color: UltramanTheme.blue, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${stats.coins}',
                          style: const TextStyle(
                            color: UltramanTheme.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          '能量币',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stats.level >= maxLevel
                          ? '已达满级'
                          : '距离升级还有 ${stats.expToNext} EXP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // 等级进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: stats.levelProgress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(UltramanTheme.gold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ===== 累计打卡 =====
            Expanded(
              flex: 2,
              child: _statItem(
                icon: Icons.flag,
                color: UltramanTheme.gold,
                label: '累计打卡',
                value: '${stats.totalCheckIns}',
              ),
            ),
            const SizedBox(width: 10),
            // ===== 本周打卡 =====
            Expanded(
              flex: 2,
              child: _statItem(
                icon: Icons.calendar_today,
                color: Colors.greenAccent,
                label: '本周打卡',
                value: '${stats.weekCheckIns}',
              ),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
