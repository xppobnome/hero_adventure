import 'dart:math' as math;

import '../data/learn_content/learn_item.dart';

/// 跟读抽题生成器。
///
/// 从对应学科字库中按 [scope] 过滤后抽取跟读条目 (去重)。
/// 支持两种模式：
/// - 顺序模式 ([ordered] = true)：按字库原始顺序返回全部条目 (拼音按顺序包含所有拼音)。
/// - 随机模式 ([ordered] = false)：随机抽取 [count] 项。
/// 随机模式下字库不足时返回可得的全部；数量非法 (<1) 时按 1 兜底。
class LearnQuizGenerator {
  final String subject;
  final String scope;
  final int count;
  final bool ordered;
  final math.Random _rng;

  LearnQuizGenerator({
    required this.subject,
    required this.scope,
    required this.count,
    this.ordered = false,
    math.Random? rng,
  }) : _rng = rng ?? math.Random();

  /// 抽取跟读条目 (去重；不足时返回可得的全部)。
  ///
  /// - 顺序模式 ([ordered] = true)：按字库原始顺序返回**全部**条目
  ///   (拼音按顺序应包含所有拼音，不受 [count] 限制)。
  /// - 随机模式 ([ordered] = false)：随机抽取 [count] 项。
  List<LearnItem> generate() {
    final pool = filterLearnTable(subject, scope);
    final safeCount = count < 1 ? 1 : count;
    if (pool.isEmpty) return const [];

    // 顺序模式：返回字库全部条目 (保持原始顺序)。
    if (ordered) return List<LearnItem>.of(pool);

    if (pool.length <= safeCount) {
      return List<LearnItem>.of(pool)..shuffle(_rng);
    }

    final picked = <LearnItem>[];
    final used = <int>{};
    // 兜底防死循环：最多尝试 count * 50 次。
    final maxAttempts = safeCount * 50;
    for (int attempt = 0;
        attempt < maxAttempts && picked.length < safeCount && used.length < pool.length;
        attempt++) {
      final idx = _rng.nextInt(pool.length);
      if (used.add(idx)) {
        picked.add(pool[idx]);
      }
    }
    return picked;
  }
}

/// 达标判定：正确数 >= ceil(总数 × passPercent / 100)。
///
/// [total] <= 0 或 [passPercent] 非法时返回 false，避免空集误发奖。
bool isLearnPassed(int correct, int total, int passPercent) {
  if (total <= 0) return false;
  if (correct < 0) return false;
  final safePercent = passPercent < 1 ? 1 : (passPercent > 100 ? 100 : passPercent);
  return correct >= (total * safePercent / 100).ceil();
}
