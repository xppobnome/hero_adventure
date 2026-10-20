import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/check_in_record.dart';
import '../../data/models/child_profile.dart';
import '../hero_system.dart' show levelFromExp, levelProgress;
import 'check_in_provider.dart';
import 'family_provider.dart';

/// 儿童看板统计结果。
class ChildStats {
  final int totalCheckIns; // 累计打卡
  final int weekCheckIns; // 本周打卡
  final int level; // 当前等级
  final int coins; // 能量币
  final int exp; // 经验值
  final double levelProgress; // 等级进度 0~1

  const ChildStats({
    required this.totalCheckIns,
    required this.weekCheckIns,
    required this.level,
    required this.coins,
    required this.exp,
    required this.levelProgress,
  });
}

/// 计算某儿童的看板统计 (派生 Provider)。
final childStatsProvider = Provider.family<ChildStats, String>((ref, childId) {
  final records = ref.watch(childCheckInProvider(childId));
  final family = ref.watch(familyProfileProvider);
  final child = family?.children.firstWhere(
        (c) => c.id == childId,
        orElse: () => ChildProfile(id: childId, name: ''),
      ) ??
      ChildProfile(id: childId, name: '');

  final completed = records.where((r) => r.status == 'completed').toList();
  final weekStart = _weekStart(DateTime.now());

  final weekCount = completed.where((r) {
    final d = DateTime.tryParse(r.date);
    return d != null && !d.isBefore(weekStart);
  }).length;

  final level = levelFromExp(child.exp);

  return ChildStats(
    totalCheckIns: completed.length,
    weekCheckIns: weekCount,
    level: level,
    coins: child.coins,
    exp: child.exp,
    levelProgress: levelProgress(child.exp),
  );
});

DateTime _weekStart(DateTime now) {
  final weekday = now.weekday; // 1=周一
  final monday = now.subtract(Duration(days: weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}
