import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/app_display.dart';
import '../../../core/utils/avatar_picker.dart';
import '../../../core/utils/native_tools.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../data/models/child_profile.dart';
import '../../../data/models/family_profile.dart';
import '../../../domain/preset_templates.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../../sync/views/sync_dashboard_view.dart';
import 'role_selection_view.dart';

/// 首次配置引导页。
///
/// 四步流程：① 设置家长防卫锁 PIN → ② 创建英雄档案 → ③ 选择防卫主题
/// → ④ 挑选任务与奖励。顶部用自定义进度条替代原 Stepper 默认样式，
/// 任务/奖励以「分类分组 + 卡片网格」展示，更直观美观。
///
/// 平板适配：内容区 maxWidth 居中；任务/奖励卡片按屏幕宽度自适应列数
/// （手机 1~2 列、平板 3~4 列），横竖屏均可用。
class FamilySetupView extends ConsumerStatefulWidget {
  const FamilySetupView({super.key});

  @override
  ConsumerState<FamilySetupView> createState() => _FamilySetupViewState();
}

class _FamilySetupViewState extends ConsumerState<FamilySetupView> {
  int _currentStep = 0;

  final _childNameController = TextEditingController();
  final _childAgeController = TextEditingController();
  String _selectedTheme = 'ultraman';
  String _avatarImage = ''; // 儿童头像本地路径 (空则占位)

  // 第 4 步：多选任务与奖励模板 (默认全不选，家长自行勾选)。
  final Set<int> _selectedTaskIndexes = {};
  final Set<int> _selectedRewardIndexes = {};

  // PIN 码用自定义数字键盘输入，避免唤起系统输入法。
  String _pin = '';
  String _confirmPin = '';
  bool _pinConfirmed = false; // false=正在输入PIN，true=正在确认PIN

  static const _stepTitles = [
    '设置防卫锁',
    '创建英雄档案',
    '选择防卫主题',
    '挑选任务与奖励',
  ];

  void _onPinKeyPress(String key) {
    if (_pinConfirmed) {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += key);
      }
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += key);
      }
    }
  }

  void _onPinDelete() {
    if (_pinConfirmed) {
      if (_confirmPin.isNotEmpty) {
        setState(
            () => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      }
    } else {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    }
  }

  void _submitRegistration() async {
    final newChild = ChildProfile(
      id: const Uuid().v4(),
      name: _childNameController.text.trim(),
      age: int.tryParse(_childAgeController.text.trim()) ?? 6,
      avatarImage: _avatarImage,
    );

    final newFamily = FamilyProfile(
      familyId: const Uuid().v4(),
      pinCode: _pin,
      currentTheme: _selectedTheme,
      children: [newChild],
    );

    await ref.read(familyProfileProvider.notifier).createFamily(newFamily);

    // 写入选中的任务模板。
    if (_selectedTaskIndexes.isNotEmpty) {
      final taskNotifier = ref.read(taskProvider.notifier);
      for (final idx in _selectedTaskIndexes) {
        final t = taskTemplates[idx];
        taskNotifier.addTask(taskFromTemplate(t, const Uuid().v4()));
      }
    }

    // 写入选中的奖励模板。
    if (_selectedRewardIndexes.isNotEmpty) {
      final rewardNotifier = ref.read(rewardProvider.notifier);
      for (final idx in _selectedRewardIndexes) {
        final r = rewardTemplates[idx];
        rewardNotifier.addReward(rewardFromTemplate(r, const Uuid().v4()));
      }
    }

    // 保存桌面快捷方式设置，并尝试创建桌面快捷方式。
    await _applyShortcut(newChild);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
      );
    }
  }

  /// 保存桌面快捷方式偏好，并（若开启）创建桌面快捷方式。
  Future<void> _applyShortcut(ChildProfile child) async {
    final storage = ref.read(storageProvider);
    // 桌面快捷方式的自定义头像/昵称已移至「家长控制台 -> 设置 -> 桌面快捷方式」，
    // 引导阶段不再提供开关，统一使用默认值（昵称作名字）。
    await storage.setShortcutUseAvatar(false);
    await storage.setShortcutUseName(true);
    await storage.setShortcutCustomName('');

    // 复用 AppDisplay 统一解析名字与图标。
    final label = AppDisplay.resolveName(storage, child);
    final iconPath = AppDisplay.resolveIconPath(storage, child);

    // 不阻塞首次配置流程：创建快捷方式会触发系统确认框（Android 8.0+），
    // 放到后台执行，避免卡住「完成并开启冒险」的页面跳转。
    unawaited(() async {
      final supported = await NativeTools.isPinnedShortcutSupported();
      if (!supported) return;
      await NativeTools.createPinnedShortcut(
        id: 'child_${child.id}',
        label: label,
        iconPath: iconPath.isEmpty ? null : iconPath,
      );
    }());
  }

  // ===== 步骤校验与推进 =====
  void _onContinue() {
    if (_currentStep == 0) {
      if (_pin.length != 4) {
        _toast('请先输入 4 位 PIN 码');
        return;
      }
      if (!_pinConfirmed) {
        setState(() => _pinConfirmed = true);
        return;
      }
      if (_confirmPin.length != 4 || _confirmPin != _pin) {
        _toast('两次 PIN 码不一致，请重新输入');
        setState(() {
          _pin = '';
          _confirmPin = '';
          _pinConfirmed = false;
        });
        return;
      }
    } else if (_currentStep == 1) {
      if (_childNameController.text.trim().isEmpty) {
        _toast('请输入英雄昵称');
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    } else {
      _submitRegistration();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        _pin = '';
        _confirmPin = '';
        _pinConfirmed = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英雄闯关计划 - 首次配置'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncDashboardView()),
              );
            },
            icon: Icon(Icons.cloud_download, color: Colors.white, size: 18.r),
            label: Text('从云端恢复',
                style: TextStyle(color: Colors.white, fontSize: 14.sp)),
          ),
        ],
      ),
      body: SafeArea(
        // 关键：SingleChildScrollView 必须在最外层（占据全部高度），
        // 内层用 Align(topCenter) 只做水平居中、垂直靠顶，避免滚动错位。
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: BoxConstraints(maxWidth: 720),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProgressHeader(),
                  SizedBox(height: 20.h),
                  _buildStepContent(),
                  SizedBox(height: 20.h),
                  _buildNavButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部进度指示器：4 个步骤圆点 + 当前步骤名 + 连接线。
  Widget _buildProgressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < 4; i++) ...[
              _buildStepDot(i),
              if (i < 3) Expanded(child: _buildStepLine(i)),
            ],
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          '第 ${_currentStep + 1} 步 · ${_stepTitles[_currentStep]}',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: UltramanTheme.deepSpace,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '共 4 步 · 完成${_currentStep + 1}/4',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStepDot(int index) {
    final done = index < _currentStep;
    final active = index == _currentStep;
    final color = done
        ? UltramanTheme.blue
        : active
            ? UltramanTheme.blue
            : Colors.grey.shade300;

    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: done || active ? UltramanTheme.blue : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: active
            ? [
                BoxShadow(
                  color: UltramanTheme.blue.withValues(alpha: 0.4),
                  blurRadius: 8,
                )
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check, color: Colors.white, size: 16.w)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade600,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildStepLine(int index) {
    final done = index < _currentStep;
    return Container(
      height: 3,
      color: done ? UltramanTheme.blue : Colors.grey.shade300,
    );
  }

  /// 当前步骤内容。
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPinStep();
      case 1:
        return _buildProfileStep();
      case 2:
        return _buildThemeStep();
      case 3:
        return _buildPresetPicker();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===== 第 1 步：PIN 防卫锁 =====
  Widget _buildPinStep() {
    final isLandscape = MediaQuery.of(context).size.width >
        MediaQuery.of(context).size.height;

    final pinIndicator = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_outlined, color: UltramanTheme.blue, size: 40.r),
        SizedBox(height: 8.h),
        Text(
          _pinConfirmed ? '请再次输入确认 PIN 码' : '请设置 4 位 PIN 码',
          style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
        ),
        SizedBox(height: 16.h),
        // PIN 圆点指示器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = _pinConfirmed
                ? index < _confirmPin.length
                : index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? const Color(0xFF00A0E9) : Colors.grey.shade300,
                border: Border.all(color: Colors.grey.shade400),
              ),
            );
          }),
        ),
      ],
    );

    final keypad = PinKeypad(
      onKeyPress: _onPinKeyPress,
      onDelete: _onPinDelete,
      keySize: isLandscape ? 48 : 56,
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        // 横屏时：左侧提示 + 右侧键盘，避免竖排溢出需要滚动。
        child: isLandscape
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: pinIndicator),
                  SizedBox(width: 32.w),
                  Flexible(flex: 2, child: keypad),
                ],
              )
            : Column(
                children: [
                  pinIndicator,
                  SizedBox(height: 20.h),
                  keypad,
                ],
              ),
      ),
    );
  }

  // ===== 第 2 步：英雄档案 =====
  Widget _buildProfileStep() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            // 头像选择 (拍照 / 上传)
            InkWell(
              onTap: () async {
                final path = await pickAvatarImage(context);
                if (path != null && mounted) {
                  setState(() => _avatarImage = path);
                }
              },
              borderRadius: BorderRadius.circular(50.r),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ChildAvatar(
                    avatarImage: _avatarImage,
                    name: _childNameController.text,
                    size: 96.w,
                  ),
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A0E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 16.w, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '点击设置头像 (可拍照或上传)',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _childNameController,
              onChanged: (_) => setState(() {}), // 头像占位实时跟随昵称
              decoration: InputDecoration(
                labelText: '英雄昵称 (例：小明)',
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _childAgeController,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: '儿童年龄 (岁)',
                helperText: '用于匹配适龄的学习题目难度',
                prefixIcon: const Icon(Icons.cake_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 第 3 步：防卫主题 =====
  Widget _buildThemeStep() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: _ThemeOption(
          title: '光之守护 (奥特曼宇宙)',
          subtitle: '包含光线攻击音效与怪兽打卡',
          selected: _selectedTheme == 'ultraman',
          onTap: () => setState(() => _selectedTheme = 'ultraman'),
        ),
      ),
    );
  }

  // ===== 底部导航按钮 =====
  Widget _buildNavButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _onBack,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                side: BorderSide(color: Colors.grey.shade400),
                foregroundColor: Colors.grey.shade700,
              ),
              child: Text('上一步', style: TextStyle(fontSize: 16.sp)),
            ),
          ),
          SizedBox(width: 16.w),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: UltramanTheme.blue,
              padding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            child: Text(
              _currentStep == 3
                  ? '完成并开启冒险'
                  : (_currentStep == 0 && _pin.length == 4 && !_pinConfirmed)
                      ? '确认 PIN 码'
                      : '下一步',
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
        ),
      ],
    );
  }

  /// 第 4 步：多选预设任务与奖励模板（分类分组 + 卡片网格）。
  Widget _buildPresetPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 任务模板 =====
        _sectionHeader(
          icon: Icons.assignment_outlined,
          title: '选择打卡任务',
          subtitle: '共 ${taskTemplates.length} 个模板，已选 ${_selectedTaskIndexes.length} 个',
          onSelectAll: () => setState(() {
            _selectedTaskIndexes
                .addAll(List.generate(taskTemplates.length, (i) => i));
          }),
          onClear: () => setState(() => _selectedTaskIndexes.clear()),
        ),
        SizedBox(height: 8.h),
        _buildTaskGrid(),
        SizedBox(height: 20.h),

        // ===== 奖励模板 =====
        _sectionHeader(
          icon: Icons.card_giftcard,
          title: '选择奖励',
          subtitle: '共 ${rewardTemplates.length} 个模板，已选 ${_selectedRewardIndexes.length} 个',
          onSelectAll: () => setState(() {
            _selectedRewardIndexes
                .addAll(List.generate(rewardTemplates.length, (i) => i));
          }),
          onClear: () => setState(() => _selectedRewardIndexes.clear()),
        ),
        SizedBox(height: 8.h),
        _buildRewardGrid(),
        SizedBox(height: 20.h),

        // ===== 桌面快捷方式（可选） =====
        _buildShortcutSection(),
      ],
    );
  }

  /// 分组标题 + 全选/清空。
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onSelectAll,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: UltramanTheme.blue, size: 20.r),
            SizedBox(width: 6.w),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            Spacer(),
            TextButton(
              onPressed: onSelectAll,
              child: Text('全选', style: TextStyle(fontSize: 13.sp)),
            ),
            TextButton(
              onPressed: onClear,
              child: Text('清空', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 26.w),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  /// 任务卡片网格（按分类分组）。
  Widget _buildTaskGrid() {
    final groups = _groupByCategory<TaskTemplate>(
      taskTemplates,
      (t) => t.category.isEmpty ? '其他' : t.category,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _categoryLabel(entry.key),
          SizedBox(height: 6.h),
          _buildTaskCards(entry.value),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }

  /// 奖励卡片网格（按分类分组）。
  Widget _buildRewardGrid() {
    final groups = _groupByCategory<RewardTemplate>(
      rewardTemplates,
      (r) => r.category.isEmpty ? '其他' : r.category,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _categoryLabel(entry.key),
          SizedBox(height: 6.h),
          _buildRewardCards(entry.value),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }

  /// 按分类分组，保持原顺序。
  Map<String, List<T>> _groupByCategory<T>(
    List<T> items,
    String Function(T) keyOf,
  ) {
    final map = <String, List<T>>{};
    for (final item in items) {
      final key = keyOf(item);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Widget _categoryLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: UltramanTheme.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// 任务卡片：用 Wrap 布局，卡片宽度按屏宽自适应，高度随内容，避免横屏溢出。
  Widget _buildTaskCards(List<TaskTemplate> templates) {
    final itemWidth = _cardItemWidth();
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final t in templates)
          SizedBox(
            width: itemWidth,
            child: _buildTaskCardItem(t),
          ),
      ],
    );
  }

  Widget _buildTaskCardItem(TaskTemplate t) {
    final globalIndex = taskTemplates.indexOf(t);
    final selected = _selectedTaskIndexes.contains(globalIndex);
    return _SelectableCard(
      selected: selected,
      onTap: () => setState(() {
        if (selected) {
          _selectedTaskIndexes.remove(globalIndex);
        } else {
          _selectedTaskIndexes.add(globalIndex);
        }
      }),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MonsterAvatar(iconName: t.iconName, size: 36),
            SizedBox(height: 8.h),
            Text(
              t.title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              '${t.rewardCoins}币/${t.rewardExp}EXP',
              style: TextStyle(
                fontSize: 11.sp,
                color: UltramanTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 奖励卡片：用 Wrap 布局，卡片宽度按屏宽自适应，高度随内容，避免横屏溢出。
  Widget _buildRewardCards(List<RewardTemplate> templates) {
    final itemWidth = _cardItemWidth();
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final r in templates)
          SizedBox(
            width: itemWidth,
            child: _buildRewardCardItem(r),
          ),
      ],
    );
  }

  Widget _buildRewardCardItem(RewardTemplate r) {
    final globalIndex = rewardTemplates.indexOf(r);
    final selected = _selectedRewardIndexes.contains(globalIndex);
    return _SelectableCard(
      selected: selected,
      onTap: () => setState(() {
        if (selected) {
          _selectedRewardIndexes.remove(globalIndex);
        } else {
          _selectedRewardIndexes.add(globalIndex);
        }
      }),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 32.r),
            SizedBox(height: 8.h),
            Text(
              r.title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              '${r.costCoins} 币',
              style: TextStyle(
                fontSize: 11.sp,
                color: UltramanTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 需审核标记
            if (r.requireApproval) ...[
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '需审核',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 计算每个卡片项的宽度（Wrap 布局用）。
  double _cardItemWidth() {
    final width = MediaQuery.of(context).size.width;
    final contentWidth = width > 760 ? 680.0 : (width - 40);
    final count = _crossAxisCount();
    // (总宽 - 间距) / 列数
    return (contentWidth - (count - 1) * 10.w) / count;
  }

  /// 按屏幕宽度计算卡片列数（平板/横屏自适应）。
  int _crossAxisCount() {
    final width = MediaQuery.of(context).size.width;
    // 内容区最大 720，去掉左右 padding 40。
    final contentWidth = width > 760 ? 680.0 : (width - 40);
    if (contentWidth >= 600) return 4;
    if (contentWidth >= 400) return 3;
    return 2;
  }

  // ===== 桌面快捷方式提示 =====
  Widget _buildShortcutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_to_home_screen, color: UltramanTheme.blue, size: 20.r),
            SizedBox(width: 6.w),
            Text(
              '桌面快捷方式',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.only(left: 26.w),
          child: Text(
            '自定义 APP 名字和图标，请在家长控制台 -> 设置 -> 桌面快捷方式 中开启。',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}

/// 可选中卡片（勾选态 + 主题色描边 + 右上角勾选标记）。
class _SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? UltramanTheme.blue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? UltramanTheme.blue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(child: Padding(padding: EdgeInsets.all(6.w), child: child)),
            // 右上角勾选标记
            Positioned(
              top: 4.w,
              right: 4.w,
              child: Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  color: selected ? UltramanTheme.blue : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? Icon(Icons.check, color: Colors.white, size: 12.w)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主题选项卡片（单选）。
class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: selected
              ? UltramanTheme.blue.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? UltramanTheme.blue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: UltramanTheme.deepSpace,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Icon(Icons.shield_outlined,
                    color: UltramanTheme.gold, size: 26.r),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13.sp, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? UltramanTheme.blue : Colors.grey.shade400,
              size: 22.r,
            ),
          ],
        ),
      ),
    );
  }
}
