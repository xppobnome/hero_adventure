import 'dart:math' as math;

/// 数学题学习逻辑。
///
/// 生成加减法题目，支持 10 以内 / 20 以内的加法、减法、加减混合，
/// 供儿童端每日学习任务使用。

/// 一道数学题。
class MathQuestion {
  final int a; // 左操作数
  final int b; // 右操作数
  final String op; // '+' 或 '-'
  final int answer; // 正确答案

  const MathQuestion({
    required this.a,
    required this.b,
    required this.op,
    required this.answer,
  });

  /// 题目文本，如 "3 + 5 = ?"。
  String get text => '$a $op $b = ?';

  /// 运算符号的中文说明。
  String get opLabel => op == '+' ? '加' : '减';
}

/// 数学题生成器。
///
/// [range] 数值范围 (10 或 20)：限制结果与操作数不超过该范围。
/// [op] 运算类型：'add' 加法 / 'sub' 减法 / 'mix' 加减混合。
/// [count] 题目数量。
class MathQuizGenerator {
  final int range;
  final String op;
  final int count;
  final math.Random _rng;

  MathQuizGenerator({
    required this.range,
    required this.op,
    required this.count,
    math.Random? rng,
  }) : _rng = rng ?? math.Random();

  /// 生成 [count] 道题 (不重复，交换等价去重，允许含 0)。
  ///
  /// 优化规则：
  /// 1. 加法：a、b 均 >= 0 (允许 9+0 / 0+9 等)；且 2+3 与 3+2 视为同一种 (交换等价去重，
  ///    即 9+0 与 0+9 也只出现一次)。
  /// 2. 减法：a >= b >= 0 (允许 9-0、9-9=0 等)。
  /// 3. 使用 Set 记录去重键，避免完全重复题；组合耗尽时提前结束返回不重复子集。
  List<MathQuestion> generate() {
    // 数值范围至少为 1
    final safeRange = range < 1 ? 1 : range;
    final questions = <MathQuestion>[];
    final seen = <String>{};

    // 最多尝试次数，避免在组合耗尽时死循环
    final maxAttempts = count * 30;

    for (int i = 0; i < count; i++) {
      MathQuestion? q;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final candidate = _generateOne(safeRange);
        final key = _dedupKey(candidate);
        if (!seen.contains(key)) {
          q = candidate;
          seen.add(key);
          break;
        }
      }
      // 若无法再生成新题 (组合耗尽)，提前结束
      if (q == null) break;
      questions.add(q);
    }
    return questions;
  }

  /// 去重键：加法按无序对 (小在前大在后) 去重，减法按有序对。
  String _dedupKey(MathQuestion q) {
    if (q.op == '+') {
      final lo = q.a < q.b ? q.a : q.b;
      final hi = q.a < q.b ? q.b : q.a;
      return '+|$lo|$hi';
    }
    return '-|${q.a}|${q.b}';
  }

  MathQuestion _generateOne(int max) {
    // 决定本次运算符号 (mix 时随机)
    final useOp = _resolveOp();
    if (useOp == '+') {
      return _generateAdd(max);
    }
    return _generateSub(max);
  }

  String _resolveOp() {
    switch (op) {
      case 'add':
        return '+';
      case 'sub':
        return '-';
      case 'mix':
      default:
        return _rng.nextBool() ? '+' : '-';
    }
  }

  /// 生成加法题：a、b >= 0、a + b <= max (允许含 0)。
  MathQuestion _generateAdd(int max) {
    final a = _rng.nextInt(max + 1); // 0..max
    final b = _rng.nextInt(max - a + 1); // 0..(max-a)，保证 a+b <= max
    return MathQuestion(a: a, b: b, op: '+', answer: a + b);
  }

  /// 生成减法题：a >= b >= 0、a <= max (允许 9-0、9-9 等)。
  MathQuestion _generateSub(int max) {
    final a = _rng.nextInt(max + 1); // 0..max
    final b = _rng.nextInt(a + 1); // 0..a，保证 a >= b >= 0
    return MathQuestion(a: a, b: b, op: '-', answer: a - b);
  }
}

/// 计算儿童作答的正确题数。
int correctCount(List<MathQuestion> questions, List<int?> answers) {
  int correct = 0;
  for (int i = 0; i < questions.length; i++) {
    if (answers.length > i && answers[i] == questions[i].answer) {
      correct++;
    }
  }
  return correct;
}
