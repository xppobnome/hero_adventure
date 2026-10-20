import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/audio_manager.dart';
import '../../../core/widgets/hero_showcase_dialog.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../domain/check_in_logic.dart';
import '../../../domain/hero_system.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../../../data/models/task.dart';
import '../widgets/child_dashboard.dart';
import '../widgets/level_map.dart';
import 'hero_gallery_view.dart';
import 'reward_shop_view.dart';
import 'math_quiz_view.dart';

/// 儿童端主界面。
///
/// 三层结构：
/// 1. 顶部看板 (等级/能量币 + 累计/本周打卡)
/// 2. 打卡内容选择 (任务列表)
/// 3. 点击任务进入该任务的「保卫萝卜式」蛇形关卡地图
///
/// 说明：本界面布局尺寸统一使用普通逻辑像素，避免 screenutil 的
/// `.w`/`.sp` 在横向平板上被放大 (scaleWidth 可达 3.6 倍) 导致
/// 溢出报错或无法滚动的问题。内容区通过 maxWidth 居中适配宽屏。
class ChildAdventureView extends ConsumerStatefulWidget {
  final String childId;
  const ChildAdventureView({super.key, required this.childId});

  @override
  ConsumerState<ChildAdventureView> createState() => _ChildAdventureViewState();
}

class _ChildAdventureViewState extends ConsumerState<ChildAdventureView> {
  Task? _selectedTask; // 当前选中的打卡内容 (null = 显示任务选择列表)
  bool _isPlayingAnimation = false;
  bool _showVictory = false; // 打卡成功时切换为胜利动画
  HeroEntry? _activeHero; // 当前出战英雄 (打卡特效/音效依据)

  String get _today {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 读取当前出战英雄 (默认初代，按等级自动兜底)。
  HeroEntry _resolveActiveHero() {
    final family = ref.read(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == widget.childId);
    final heroId = child?.currentHeroId ?? 'ace';
    final hero = heroById(heroId);
    if (hero != null) return hero;
    // 兜底：取当前等级能解锁的最高英雄
    final level = child == null ? 1 : levelFromExp(child.exp);
    return highestUnlockedHero(level);
  }

  /// 关卡状态判定 (基于统一周期校验逻辑)。
  String _nodeStatus(Task task) {
    final records = ref.read(checkInProvider);
    if (CheckInLogic.isCompleted(
      task: task,
      childId: widget.childId,
      date: _today,
      records: records,
    )) {
      return 'completed';
    }
    if (CheckInLogic.isPending(
      task: task,
      childId: widget.childId,
      date: _today,
      records: records,
    )) {
      return 'pending';
    }
    if (!CheckInLogic.isAvailable(
      task: task,
      childId: widget.childId,
      date: _today,
      records: records,
    )) {
      return 'locked';
    }
    return 'available';
  }

  Future<void> _handleCheckIn(Task task) async {
    if (_isPlayingAnimation) return;
    setState(() {
      _isPlayingAnimation = true;
      _showVictory = false;
    });

    // 依据当前出战英雄确定出战对象
    final hero = _resolveActiveHero();
    _activeHero = hero;

    // 先弹出英雄展示弹窗 + 播放变身/技能音效，声音结束后关闭弹窗
    await _showHeroShowcase(hero);

    String? proofImage;
    if (task.requirePhoto) {
      proofImage = await _pickPhoto();
      if (proofImage == null) {
        if (mounted) setState(() => _isPlayingAnimation = false);
        return;
      }
    }

    await ref.read(checkInProvider.notifier).addCheckIn(
          childId: widget.childId,
          taskId: task.id,
          requirePhoto: task.requirePhoto,
          rewardCoins: task.rewardCoins,
          rewardExp: task.rewardExp,
          proofImage: proofImage,
        );

    if (!task.requirePhoto) {
      await ref.read(familyProfileProvider.notifier).updateChildExp(
            widget.childId,
            task.rewardExp,
            task.rewardCoins,
          );
    }

    if (mounted) {
      if (task.requirePhoto) {
        setState(() => _isPlayingAnimation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('证据已上传！等待宇宙警备队 (家长) 审核', style: TextStyle(fontSize: 14)),
            backgroundColor: UltramanTheme.blue,
          ),
        );
      } else {
        // 打卡成功：播放 victory 音效 + 展示胜利动画
        AudioManager().playVictory();
        setState(() => _showVictory = true);
        await Future.delayed(const Duration(milliseconds: 1600));
        if (!mounted) return;
        setState(() {
          _isPlayingAnimation = false;
          _showVictory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('怪兽已被消灭！获得 ${task.rewardExp} 经验 / ${task.rewardCoins} 币', style: const TextStyle(fontSize: 14)),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 弹出英雄展示弹窗 + 播放变身/技能音效，声音结束后关闭弹窗。
  Future<void> _showHeroShowcase(HeroEntry hero) async {
    // 先展示弹窗 (点击即显)
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '英雄变身',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return HeroShowcaseDialog(hero: hero, badgeText: '变身！');
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );

    // 同时播放变身 + 技能音效；声音结束 (playSkill 完成) 后关闭弹窗
    AudioManager().playTransform();
    try {
      await AudioManager().playSkill(hero);
    } catch (_) {}
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) return picked.path;
    return null;
  }

  void _showUnlockDeviceDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('安全锁 - 解除设备绑定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: '请输入家长 PIN 码解锁'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final correctPin = ref.read(familyProfileProvider)?.pinCode ?? '0000';
              if (pinController.text == correctPin) {
                ref.read(deviceRoleProvider.notifier).state = 'unbound';
                ref.read(storageProvider).saveDeviceRole('unbound');
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('警报！密码错误！')));
              }
            },
            child: const Text('确认解除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == widget.childId);

    if (child == null) return const Scaffold(body: Center(child: Text('数据异常')));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTask == null ? '地球防卫图 - ${child.name}' : _selectedTask!.title,
          style: const TextStyle(fontSize: 18),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            _selectedTask == null ? Icons.lock_outline : Icons.arrow_back,
            size: 24,
          ),
          onPressed: _selectedTask == null
              ? _showUnlockDeviceDialog
              : () => setState(() => _selectedTask = null),
        ),
        backgroundColor: UltramanTheme.deepSpace,
        actions: [
          if (_selectedTask == null) ...[
            IconButton(
              icon: const Icon(Icons.store, size: 24),
              tooltip: '能量兑换站',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RewardShopView(childId: widget.childId)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 24),
              tooltip: '英雄图鉴',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HeroGalleryView(childId: widget.childId)),
                );
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: UltramanStarfield()),
          // 主体：看板固定在顶部，下方切换「任务选择」或「关卡地图」
          Column(
            children: [
              // 顶部看板
              ChildDashboard(childId: widget.childId),
              // 主体内容区
              Expanded(
                child: _selectedTask == null
                    ? SafeArea(top: false, child: _buildTaskSelection(tasks))
                    : _buildLevelMap(_selectedTask!),
              ),
            ],
          ),
          // 攻击/胜利特效覆盖层 (跟随当前出战英雄)
          if (_isPlayingAnimation)
            Positioned.fill(
              child: _showVictory
                  ? VictoryEffect(hero: _activeHero)
                  : BeamAttackEffect(hero: _activeHero),
            ),
        ],
      ),
    );
  }

  /// 打卡内容选择 (任务列表)。
  Widget _buildTaskSelection(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          '暂无防卫任务，等待家长下达',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final status = _nodeStatus(task);
            final isCheckinWeek = task.type == 'checkin_week';
            final weekProgress = isCheckinWeek
                ? CheckInLogic.checkinWeekProgress(
                    task: task,
                    childId: widget.childId,
                    records: ref.read(checkInProvider),
                  )
                : null;

            return _buildTaskCard(task, status, isCheckinWeek, weekProgress);
          },
        ),
      ),
    );
  }

  /// 单个打卡内容卡片。
  Widget _buildTaskCard(
    Task task,
    String status,
    bool isCheckinWeek,
    String? weekProgress,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor(status), width: 2),
      ),
      child: InkWell(
        onTap: () {
          // 数学题学习任务：直接进入做题界面 (当天已完成仍可练习，但不再发奖励)
          if (task.isMathTask) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MathQuizView(childId: widget.childId, task: task),
              ),
            );
          } else {
            setState(() => _selectedTask = task);
          }
        },
        child: Row(
          children: [
            if (task.isMathTask)
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: UltramanTheme.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate, color: Colors.white, size: 28),
              )
            else
              MonsterAvatar(iconName: task.iconName, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '奖励: ${task.rewardCoins}币 / ${task.rewardExp}EXP · ${task.cycleDescription}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (isCheckinWeek) ...[
                    const SizedBox(height: 4),
                    Text(
                      '连续打卡进度: $weekProgress',
                      style: const TextStyle(
                        fontSize: 12,
                        color: UltramanTheme.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildTaskStatusIcon(status),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return UltramanTheme.gold;
      case 'locked':
        return Colors.grey;
      default:
        return UltramanTheme.blue;
    }
  }

  Widget _buildTaskStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case 'pending':
        return Icon(Icons.hourglass_top, color: UltramanTheme.gold, size: 24);
      case 'locked':
        return const Icon(Icons.lock, color: Colors.grey, size: 24);
      default:
        return Icon(Icons.chevron_right, color: UltramanTheme.blue, size: 28);
    }
  }

  /// 关卡地图区：显示当前选中任务的蛇形选关地图 + 打卡按钮。
  Widget _buildLevelMap(Task task) {
    final status = _nodeStatus(task);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Expanded(
              child: LevelMap(task: task, childId: widget.childId),
            ),
            // 底部打卡按钮
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _buildCheckInButton(task, status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInButton(Task task, String status) {
    switch (status) {
      case 'completed':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('今日已通关', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: UltramanTheme.gold.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('待家长审核中', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case 'locked':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: const Text('今日不可打卡', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        );
      default:
        return ElevatedButton(
          onPressed: () => _handleCheckIn(task),
          style: ElevatedButton.styleFrom(
            backgroundColor: UltramanTheme.blue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('光线攻击', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        );
    }
  }
}
