import '../data/models/reward_item.dart';
import '../data/models/task.dart';

/// 首次配置时的预设任务模板（内容丰富，家长可多选）。
///
/// 每个模板包含标题、图标名、奖励、周期类型、分类，供首次进入时
/// 一键勾选，避免后续逐个手动添加。
class TaskTemplate {
  final String title;
  final String iconName;
  final int rewardCoins;
  final int rewardExp;
  final String type;
  final bool requirePhoto;
  final String category; // 分类，用于引导界面分组展示

  const TaskTemplate({
    required this.title,
    required this.iconName,
    required this.rewardCoins,
    required this.rewardExp,
    required this.type,
    this.requirePhoto = false,
    this.category = '',
  });
}

/// 预设任务模板列表（覆盖生活自理 / 学习 / 运动 / 品德 / 每周等）。
const List<TaskTemplate> taskTemplates = [
  // ===== 生活自理 =====
  TaskTemplate(title: '消灭蛀牙怪兽 (认真刷牙)', iconName: 'tooth_monster', rewardCoins: 10, rewardExp: 50, type: 'daily', category: '生活自理'),
  TaskTemplate(title: '整理防卫基地 (收拾房间)', iconName: 'mess_monster', rewardCoins: 15, rewardExp: 60, type: 'daily', category: '生活自理'),
  TaskTemplate(title: '独立穿衣小英雄 (自己穿衣)', iconName: 'cloth_monster', rewardCoins: 10, rewardExp: 50, type: 'daily', category: '生活自理'),
  TaskTemplate(title: '餐具归位 (自己收拾碗筷)', iconName: 'dish_monster', rewardCoins: 8, rewardExp: 40, type: 'daily', category: '生活自理'),
  TaskTemplate(title: '按时洗澡打怪兽 (睡前洗漱)', iconName: 'bath_monster', rewardCoins: 10, rewardExp: 50, type: 'daily', category: '生活自理'),
  TaskTemplate(title: '早睡早起 (按时睡觉起床)', iconName: 'sleep_monster', rewardCoins: 15, rewardExp: 60, type: 'daily', category: '生活自理'),

  // ===== 学习任务 =====
  TaskTemplate(title: '阅读小英雄 (阅读绘本 20 分钟)', iconName: 'book_monster', rewardCoins: 20, rewardExp: 80, type: 'daily', category: '学习'),
  TaskTemplate(title: '写字小英雄 (练习写字)', iconName: 'write_monster', rewardCoins: 20, rewardExp: 80, type: 'daily', category: '学习'),
  TaskTemplate(title: '英语小英雄 (英语启蒙)', iconName: 'abc_monster', rewardCoins: 20, rewardExp: 80, type: 'daily', category: '学习'),
  TaskTemplate(title: '认真完成作业', iconName: 'homework_monster', rewardCoins: 25, rewardExp: 100, type: 'daily', category: '学习'),
  TaskTemplate(title: '每日数学题挑战', iconName: 'math_monster', rewardCoins: 20, rewardExp: 80, type: 'math', category: '学习'),

  // ===== 运动锻炼 =====
  TaskTemplate(title: '户外运动小英雄 (跳绳/跑步)', iconName: 'run_monster', rewardCoins: 20, rewardExp: 80, type: 'daily', category: '运动'),
  TaskTemplate(title: '帮助做家务 (扫地/擦桌)', iconName: 'clean_monster', rewardCoins: 15, rewardExp: 60, type: 'daily', category: '运动'),

  // ===== 品德养成 =====
  TaskTemplate(title: '礼貌小英雄 (主动问好)', iconName: 'polite_monster', rewardCoins: 10, rewardExp: 50, type: 'daily', category: '品德'),
  TaskTemplate(title: '分享小英雄 (分享玩具零食)', iconName: 'share_monster', rewardCoins: 10, rewardExp: 50, type: 'daily', category: '品德'),

  // ===== 每周任务 =====
  TaskTemplate(title: '周末户外探险 (亲近自然)', iconName: 'nature_monster', rewardCoins: 50, rewardExp: 200, type: 'weekly', category: '每周'),
  TaskTemplate(title: '整理书桌与书架', iconName: 'desk_monster', rewardCoins: 30, rewardExp: 120, type: 'weekly', category: '每周'),
  TaskTemplate(title: '亲子阅读时光 (每周 3 次)', iconName: 'family_monster', rewardCoins: 40, rewardExp: 150, type: 'weekly', category: '每周'),
];

/// 预设奖励模板列表（内容丰富，家长可多选）。
class RewardTemplate {
  final String title;
  final int costCoins;
  final String iconName;
  final String category; // 分类，用于引导界面分组展示
  final bool requireApproval; // 是否需要家长审核（false = 兑换即发放）

  const RewardTemplate({
    required this.title,
    required this.costCoins,
    required this.iconName,
    this.category = '',
    this.requireApproval = true,
  });
}

/// 预设奖励模板（覆盖娱乐 / 零食 / 玩具 / 出行 / 亲子时光等）。
///
/// 小额、即时性的娱乐/零食类奖励默认「免审核」（兑换即发放），
/// 金额较大或涉及出行的奖励保留「需审核」。
const List<RewardTemplate> rewardTemplates = [
  RewardTemplate(title: '看动画片 30 分钟', costCoins: 100, iconName: 'tv_icon', category: '娱乐', requireApproval: false),
  RewardTemplate(title: '玩手机游戏 20 分钟', costCoins: 150, iconName: 'game_icon', category: '娱乐'),
  RewardTemplate(title: '买一个喜欢的玩具', costCoins: 300, iconName: 'toy_icon', category: '玩具'),
  RewardTemplate(title: '吃一根冰淇淋', costCoins: 80, iconName: 'ice_icon', category: '零食', requireApproval: false),
  RewardTemplate(title: '吃一顿喜欢的零食', costCoins: 120, iconName: 'snack_icon', category: '零食', requireApproval: false),
  RewardTemplate(title: '去游乐园玩一次', costCoins: 1000, iconName: 'park_icon', category: '出行'),
  RewardTemplate(title: '看一场电影', costCoins: 500, iconName: 'movie_icon', category: '娱乐'),
  RewardTemplate(title: '买一本新绘本', costCoins: 250, iconName: 'book_icon', category: '玩具'),
  RewardTemplate(title: '和爸爸妈妈露营', costCoins: 1500, iconName: 'camp_icon', category: '出行'),
  RewardTemplate(title: '晚睡 30 分钟', costCoins: 100, iconName: 'moon_icon', category: '娱乐', requireApproval: false),
  RewardTemplate(title: '骑自行车兜风', costCoins: 200, iconName: 'bike_icon', category: '出行'),
  RewardTemplate(title: '去动物园看动物', costCoins: 800, iconName: 'zoo_icon', category: '出行'),
];

/// 把选中的任务模板转换为 Task 对象。
Task taskFromTemplate(TaskTemplate t, String id) {
  return Task(
    id: id,
    title: t.title,
    iconName: t.iconName,
    rewardCoins: t.rewardCoins,
    rewardExp: t.rewardExp,
    type: t.type,
    requirePhoto: t.requirePhoto,
    mathRange: 10,
    mathOp: 'mix',
    mathCount: 10,
    mathPassPercent: 100,
  );
}

/// 把选中的奖励模板转换为 RewardItem 对象。
RewardItem rewardFromTemplate(RewardTemplate r, String id) {
  return RewardItem(
    id: id,
    title: r.title,
    costCoins: r.costCoins,
    iconName: r.iconName,
    requireApproval: r.requireApproval,
  );
}
