/// 任务模型。
///
/// 周期类型 [type] 扩展为以下枚举：
/// - `daily`  每日任务
/// - `weekly` 每周任务
/// - `once`   单次/紧急委托
/// - `checkin_week` 打卡一周 (连续打卡满一周)
/// - `custom_days`  打卡指定日期 (家长选择一周内的具体星期几)
/// - `math`   每日数学题学习 (儿童作答后判定)
///
/// 完成后可指定奖励 [rewardId]，为空则默认发放 [rewardCoins]/[rewardExp]。
class Task {
  final String id;
  final String title;
  final String iconName;
  final int rewardCoins;
  final int rewardExp;
  final String type;
  final bool requirePhoto;

  // ===== 新增扩展字段 (向后兼容默认值) =====
  final List<int> selectedDays; // 当 type == 'custom_days' 时，选中的星期几 (1=周一 ... 7=周日)
  final String? rewardId; // 完成后指定的奖励项 ID (关联 RewardItem)

  // ===== 数学题任务字段 (type == 'math' 时生效) =====
  final int mathRange; // 题目数值范围：10 或 20
  final String mathOp; // 运算类型：'add' / 'sub' / 'mix'
  final int mathCount; // 每天需完成的题目数量
  final int mathPassPercent; // 答对题数百分比阈值 (默认 100，即全对才发奖励)

  Task({
    required this.id,
    required this.title,
    required this.iconName,
    required this.rewardCoins,
    required this.rewardExp,
    required this.type,
    this.requirePhoto = false,
    this.selectedDays = const [],
    this.rewardId,
    this.mathRange = 10,
    this.mathOp = 'add',
    this.mathCount = 10,
    this.mathPassPercent = 100,
  });

  /// 是否为数学题学习任务。
  bool get isMathTask => type == 'math';

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      iconName: json['iconName'] as String,
      rewardCoins: json['rewardCoins'] as int,
      rewardExp: json['rewardExp'] as int,
      type: json['type'] as String,
      requirePhoto: json['requirePhoto'] as bool? ?? false,
      selectedDays: (json['selectedDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      rewardId: json['rewardId'] as String?,
      mathRange: json['mathRange'] as int? ?? 10,
      mathOp: json['mathOp'] as String? ?? 'add',
      mathCount: json['mathCount'] as int? ?? 10,
      mathPassPercent: json['mathPassPercent'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconName': iconName,
      'rewardCoins': rewardCoins,
      'rewardExp': rewardExp,
      'type': type,
      'requirePhoto': requirePhoto,
      'selectedDays': selectedDays,
      'rewardId': rewardId,
      'mathRange': mathRange,
      'mathOp': mathOp,
      'mathCount': mathCount,
      'mathPassPercent': mathPassPercent,
    };
  }

  /// 周期类型的中文说明。
  String get typeLabel {
    switch (type) {
      case 'daily':
        return '每日任务';
      case 'weekly':
        return '每周任务';
      case 'once':
        return '单次任务';
      case 'checkin_week':
        return '打卡一周';
      case 'custom_days':
        return '打卡指定日期';
      case 'math':
        return '每日数学题';
      default:
        return type;
    }
  }

  /// 判断该任务在指定星期几 (1-7) 是否应执行。
  bool isActiveOnDay(int weekday) {
    switch (type) {
      case 'daily':
        return true;
      case 'math':
        return true;
      case 'custom_days':
        return selectedDays.contains(weekday);
      case 'checkin_week':
      case 'weekly':
        return true; // 每周任务一周内任意完成；打卡一周需累计满7天
      case 'once':
        return true;
      default:
        return true;
    }
  }

  /// 周期类型的中文周期规则说明 (用于家长端与儿童端展示)。
  String get cycleDescription {
    switch (type) {
      case 'daily':
        return '每天都可以打卡';
      case 'math':
        return '每天做 $mathCount 道数学题';
      case 'weekly':
        return '每周内任意完成一次';
      case 'once':
        return '仅需完成一次';
      case 'checkin_week':
        return '连续打卡满一周 (7 天)';
      case 'custom_days':
        final names = selectedDays.map(_weekdayName).join('、');
        return names.isEmpty ? '未选择打卡日期' : '每周 $names 打卡';
      default:
        return type;
    }
  }

  static String _weekdayName(int day) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return (day >= 1 && day <= 7) ? names[day - 1] : '?';
  }
}
