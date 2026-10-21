import 'dart:math' as math;

/// 数学题学习逻辑。
///
/// 生成加减法题目，支持 10 以内 / 20 以内的加法、减法、加减混合，
/// 供儿童端每日学习任务使用。
///
/// 「加减混合」(mix) 采用三数连算（如 2+1-3），其余为两数运算。

/// 一道数学题。
class MathQuestion {
  final int a; // 左操作数
  final int b; // 右操作数
  final String op; // '+' 或 '-'
  final int answer; // 正确答案

  // 三数连算（仅 mix 时使用）：第三个操作数 + 第二个运算符。
  final int? c;
  final String? op2;

  const MathQuestion({
    required this.a,
    required this.b,
    required this.op,
    required this.answer,
    this.c,
    this.op2,
  });

  /// 题目文本，如 "3 + 5 = ?" 或 "2 + 1 - 3 = ?"。
  String get text {
    if (c != null && op2 != null) {
      return '$a $op $b $op2 $c = ?';
    }
    return '$a $op $b = ?';
  }

  /// 运算符号的中文说明。
  String get opLabel {
    if (c != null && op2 != null) return '加减混合';
    return op == '+' ? '加' : '减';
  }
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
    if (q.c != null && q.op2 != null) {
      // 三数连算：按完整表达式去重。
      return '${q.a}${q.op}${q.b}${q.op2}${q.c}';
    }
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
    if (useOp == '-') {
      return _generateSub(max);
    }
    // mix：三数连算 (如 2+1-3)
    return _generateThree(max);
  }

  String _resolveOp() {
    switch (op) {
      case 'add':
        return '+';
      case 'sub':
        return '-';
      case 'mix':
      default:
        return 'mix';
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

  /// 生成三数连算题 (加减混合)：a op1 b op2 c，全程结果与操作数保持非负且 <= max。
  ///
  /// 例如 2+1-3=0、5-2+3=6、9-4-2=3 等。op1/op2 随机取 + 或 -，
  /// 每一步的中间结果都保证非负且不超过 max，避免负数 / 超范围。
  MathQuestion _generateThree(int max) {
    for (int attempt = 0; attempt < 50; attempt++) {
      final op1 = _rng.nextBool() ? '+' : '-';
      final op2 = _rng.nextBool() ? '+' : '-';

      final a = _rng.nextInt(max + 1);
      final b = _rng.nextInt(max + 1);

      // 第一步：a op1 b
      int mid;
      if (op1 == '+') {
        mid = a + b;
        if (mid > max) continue;
      } else {
        mid = a - b;
        if (mid < 0) continue;
      }

      // 第二步：mid op2 c
      int c;
      int answer;
      if (op2 == '+') {
        // mid + c <= max
        final upperC = max - mid;
        if (upperC < 0) continue;
        c = _rng.nextInt(upperC + 1);
        answer = mid + c;
      } else {
        // mid - c >= 0
        c = _rng.nextInt(mid + 1);
        answer = mid - c;
      }

      return MathQuestion(
        a: a,
        b: b,
        op: op1,
        answer: answer,
        c: c,
        op2: op2,
      );
    }
    // 兜底：极端情况下回退到简单的两数加法。
    return _generateAdd(max);
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
