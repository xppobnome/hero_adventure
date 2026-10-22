import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/audio_manager.dart';
import '../../../core/utils/image_compressor.dart';
import '../../../core/widgets/hero_showcase_dialog.dart';
import '../../../core/widgets/pin_input_dialog.dart';
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
import 'child_settings_view.dart';

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
    List<String> proofImages = const [];
    if (task.requirePhoto) {
      proofImages = await _pickPhotos();
      if (proofImages.isEmpty) {
        if (mounted) setState(() => _isPlayingAnimation = false);
        return;
      }
      proofImage = proofImages.first;
    }

    await ref
        .read(checkInProvider.notifier)
        .addCheckIn(
          childId: widget.childId,
          taskId: task.id,
          requirePhoto: task.requirePhoto,
          rewardCoins: task.rewardCoins,
          rewardExp: task.rewardExp,
          proofImage: proofImage,
          proofImages: proofImages,
        );

    if (!task.requirePhoto) {
      await ref
          .read(familyProfileProvider.notifier)
          .updateChildExp(widget.childId, task.rewardExp, task.rewardCoins);
    }

    if (mounted) {
      if (task.requirePhoto) {
        setState(() => _isPlayingAnimation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '证据已上传！等待宇宙警备队 (家长) 审核',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: UltramanTheme.blue,
          ),
        );
      } else {
        // 打卡成功：播放 victory 音效 + 展示庆祝祝贺动画
        AudioManager().playVictory();
        setState(() => _showVictory = true);
        // 庆祝动画由 CelebrationEffect 的 onCompleted 回调关闭覆盖层，
        // 这里等待动画时长 (约 2400ms) 后复位状态并提示奖励。
        await Future.delayed(const Duration(milliseconds: 2400));
        if (!mounted) return;
        setState(() {
          _isPlayingAnimation = false;
          _showVictory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '怪兽已被消灭！获得 ${task.rewardExp} 经验 / ${task.rewardCoins} 币',
              style: const TextStyle(fontSize: 14),
            ),
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
        return HeroShowcaseDialog(hero: hero, badgeText: '战斗胜利');
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
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
    if (picked == null) return null;
    // 复制到持久目录，避免 cache 临时文件被清理后凭证读不到/无法备份。
    return ImageCompressor.persistPickedImage(picked.path);
  }

  /// 多张照片打卡流程：底部弹窗展示已拍照片，可继续拍照、删除单张，
  /// 点「提交打卡」返回照片列表。取消则返回空列表。
  Future<List<String>> _pickPhotos() async {
    final List<String> images = [];
    // 先拍第一张，拍不到则视为取消。
    final first = await _pickPhoto();
    if (first == null) return images;
    images.add(first);

    // 底部弹窗：展示已拍照片，可继续拍、删除、提交。
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiPhotoSheet(initialImages: images),
    );

    return result ?? const [];
  }

  Future<void> _showUnlockDeviceDialog() async {
    debugPrint('[PIN解除] 打开解除绑定对话框，deviceRole=${ref.read(deviceRoleProvider)}, childId=${widget.childId}');
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (ctx) => PinInputDialog(
        title: '安全锁 - 解除设备绑定',
        subtitle: '请输入家长 PIN 码解锁',
        onSubmit: (pin) async {
          final correctPin =
              ref.read(familyProfileProvider)?.pinCode ?? '0000';
          if (pin == correctPin) {
            // 仅返回 true 让对话框关闭；状态更新与导航放到对话框关闭后，
            // 避免更新 deviceRole 触发 InitialRouteWrapper 重建、提前销毁
            // 本 State 导致对话框 Future 悬挂或导航失效。
            debugPrint('[PIN解除] PIN 正确，返回 true（暂不改状态）');
            return true;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('警报！密码错误！')));
          return false;
        },
      ),
    );

    debugPrint('[PIN解除] showDialog 返回 unlocked=$unlocked, mounted=$mounted');
    if (unlocked != true || !mounted) return;

    debugPrint('[PIN解除] 更新前 deviceRole=${ref.read(deviceRoleProvider)}');

    // 先取得 root navigator 引用，避免下面 deviceRole 变化触发 home 重建、
    // 本 State 被 dispose 后 context 失效，导致 popUntil 无法执行。
    final navigator = Navigator.of(context, rootNavigator: true);
    debugPrint('[PIN解除] 已取得 rootNavigator');

    // 更新设备角色为 unbound 并持久化（await 确保持久化完成，避免竞态）。
    ref.read(deviceRoleProvider.notifier).state = 'unbound';
    await ref.read(storageProvider).saveDeviceRole('unbound');
    debugPrint('[PIN解除] 更新后 deviceRole=${ref.read(deviceRoleProvider)}');

    if (!mounted) {
      debugPrint('[PIN解除] 更新后 mounted=false，提前返回（可能已被 home 重建 dispose）');
      return;
    }

    // 用 root navigator 弹回根（home = InitialRouteWrapper）。
    debugPrint('[PIN解除] popUntil 前 canPop=${navigator.canPop()}');
    navigator.popUntil((route) => route.isFirst);
    debugPrint('[PIN解除] popUntil 完成');
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == widget.childId);

    if (child == null) return const Scaffold(body: Center(child: Text('数据异常')));

    return PopScope(
      // 在关卡地图界面时，系统返回键拦截为「返回任务列表」；
      // 在任务列表界面时允许正常返回 (交给上层路由处理)。
      canPop: _selectedTask == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedTask != null) {
          setState(() => _selectedTask = null);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTask == null
              ? '地球防卫图 - ${child.name}'
              : _selectedTask!.title,
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
                  MaterialPageRoute(
                    builder: (_) => RewardShopView(childId: widget.childId),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 24),
              tooltip: '英雄图鉴',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeroGalleryView(childId: widget.childId),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 24),
              tooltip: '设置',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildSettingsView(childId: widget.childId),
                  ),
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
          // 攻击/庆祝特效覆盖层 (跟随当前出战英雄)
          if (_isPlayingAnimation)
            Positioned.fill(
              child: _showVictory
                  ? CelebrationEffect(
                      title: '战斗胜利',
                      subtitle: '获得奖励',
                      onCompleted: () {
                        if (mounted) {
                          setState(() {
                            _isPlayingAnimation = false;
                            _showVictory = false;
                          });
                        }
                      },
                    )
                  : BeamAttackEffect(hero: _activeHero),
            ),
        ],
      ),
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
            final isCheckinMonth = task.type == 'checkin_month';
            final isCheckinStreak = isCheckinWeek || isCheckinMonth;
            final weekProgress = isCheckinStreak
                ? CheckInLogic.checkinProgress(
                    task: task,
                    childId: widget.childId,
                    records: ref.read(checkInProvider),
                  )
                : null;

            return _buildTaskCard(task, status, isCheckinStreak, weekProgress);
          },
        ),
      ),
    );
  }

  /// 单个打卡内容卡片。
  Widget _buildTaskCard(
    Task task,
    String status,
    bool isCheckinStreak,
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
                builder: (_) =>
                    MathQuizView(childId: widget.childId, task: task),
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
                child: const Icon(
                  Icons.calculate,
                  color: Colors.white,
                  size: 28,
                ),
              )
            else
              MonsterAvatar(iconName: task.iconName, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.requirePhoto) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera, size: 12, color: Colors.orange),
                              SizedBox(width: 2),
                              Text(
                                '需拍照',
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
                  const SizedBox(height: 4),
                  Text(
                    '奖励: ${task.rewardCoins}币 / ${task.rewardExp}EXP · ${task.cycleDescription}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (isCheckinStreak) ...[
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
              Text(
                '今日已通关',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              Text(
                '待家长审核中',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          child: const Text(
            '今日不可打卡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      default:
        return ElevatedButton(
          onPressed: () => _handleCheckIn(task),
          style: ElevatedButton.styleFrom(
            backgroundColor: UltramanTheme.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                '光线攻击',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// 多张照片打卡编辑底部弹窗。
///
/// 展示已拍照片缩略图，支持「继续拍照」追加、单张删除，点「提交打卡」
/// 返回照片列表；点「取消」返回 null（丢弃本次拍照）。
class _MultiPhotoSheet extends StatefulWidget {
  final List<String> initialImages;
  const _MultiPhotoSheet({required this.initialImages});

  @override
  State<_MultiPhotoSheet> createState() => _MultiPhotoSheetState();
}

class _MultiPhotoSheetState extends State<_MultiPhotoSheet> {
  late final List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = List.of(widget.initialImages);
  }

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final path = await ImageCompressor.persistPickedImage(picked.path);
    if (mounted) setState(() => _images.add(path));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '打卡凭证照片',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '已拍 ${_images.length} 张',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '可拍摄多张照片作为打卡凭证，点击照片右上角可删除',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          if (_images.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('还没有照片，点击下方「继续拍照」', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final path = _images[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_a_photo, size: 20),
                  label: const Text('继续拍照'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: UltramanTheme.blue,
                    side: const BorderSide(color: UltramanTheme.blue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _images.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(List.of(_images)),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('提交打卡'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
