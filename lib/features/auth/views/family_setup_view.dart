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
import '../../../data/models/child_profile.dart';
import '../../../data/models/family_profile.dart';
import '../../../domain/preset_templates.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../sync/views/sync_dashboard_view.dart';
import 'role_selection_view.dart';

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

  // 第 4 步：多选任务与奖励模板 (默认全选常用项)。
  final Set<int> _selectedTaskIndexes = {
    for (int i = 0; i < taskTemplates.length; i++)
      if (i < 10) i, // 默认勾选前 10 个常用任务
  };
  final Set<int> _selectedRewardIndexes = {
    for (int i = 0; i < rewardTemplates.length; i++)
      if (i < 6) i, // 默认勾选前 6 个常用奖励
  };

  // 桌面快捷方式设置：是否用儿童头像作图标 / 用昵称作名字。
  bool _shortcutUseAvatar = false;
  bool _shortcutUseName = true;
  String _shortcutCustomName = '';

  final _shortcutNameController = TextEditingController();

  // PIN 码用自定义数字键盘输入，避免唤起系统输入法。
  String _pin = '';
  String _confirmPin = '';
  bool _pinConfirmed = false; // false=正在输入PIN，true=正在确认PIN

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
        setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
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
    await storage.setShortcutUseAvatar(_shortcutUseAvatar);
    await storage.setShortcutUseName(_shortcutUseName);
    await storage.setShortcutCustomName(_shortcutCustomName);

    // 首次配置中若启用了自定义头像或昵称，则默认同步开启
    // 「启动图/关于页显示自定义内容」，让自定义内容全局生效。
    if (_shortcutUseAvatar || _shortcutUseName || _shortcutCustomName.isNotEmpty) {
      await storage.setUseCustomAppDisplay(true);
    }

    // 复用 AppDisplay 统一解析名字与图标。
    final label = AppDisplay.resolveName(storage, child);
    final iconPath = AppDisplay.resolveIconPath(storage, child);

    // 不阻塞首次配置流程：创建快捷方式会触发系统确认框（Android 8.0+），
    // 放到后台执行，避免卡住「完成并开启冒险」的页面跳转。
    // 先检查设备是否支持，不支持则静默跳过（不打扰首次配置）。
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
            label: Text('从云端恢复', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
          ),
        ],
      ),
      body: SafeArea(
        // 关键：SingleChildScrollView 必须在最外层（占据全部高度），
        // 内层用 Align(topCenter) 只做水平居中、垂直靠顶。若用 Center
        // 包裹滚动视图（反过来），或滚动视图内用 Center，都会因滚动轴
        // 方向为无限高度而产生垂直居中错位，导致内容超出屏幕时无法
        // 滚到最底部（平板端尤其明显）。
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              constraints: BoxConstraints(maxWidth: 560),
              child: Stepper(
              type: StepperType.vertical,
              // 关键：Stepper 内部是一个 shrinkWrap 的 ListView，默认带可滚动
              // physics（Android 为 ClampingScrollPhysics），会抢占滚动手势，
              // 导致外层 SingleChildScrollView 无法滚到最底部。这里禁用它，
              // 让整个引导页由外层统一滚动。
              physics: const NeverScrollableScrollPhysics(),
              currentStep: _currentStep,
              // 【统一样式】：重写底部按钮栏，自动适配 main.dart 中的 ElevatedButtonTheme
              controlsBuilder: (context, details) {
                return Padding(
                  padding: EdgeInsets.only(top: 24.h),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(
                            _currentStep == 3
                                ? '完成并开启冒险'
                                : (_currentStep == 0 && _pin.length == 4 && !_pinConfirmed)
                                    ? '确认 PIN 码'
                                    : '下一步',
                            style: TextStyle(fontSize: 16.sp)
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        SizedBox(width: 16.w),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(
                              '上一步',
                              style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade700)
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              },
              onStepContinue: () {
                if (_currentStep == 0) {
                  // 尚未完成 PIN 输入
                  if (_pin.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入4位 PIN 码')));
                    return;
                  }
                  // 已输入 PIN 但尚未确认
                  if (!_pinConfirmed) {
                    setState(() => _pinConfirmed = true);
                    return;
                  }
                  // 校验确认 PIN 是否一致
                  if (_confirmPin.length != 4 || _confirmPin != _pin) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次 PIN 码不一致，请重新输入')));
                    setState(() {
                      _pin = '';
                      _confirmPin = '';
                      _pinConfirmed = false;
                    });
                    return;
                  }
                } else if (_currentStep == 1) {
                  if (_childNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入儿童昵称')));
                    return;
                  }
                }

                if (_currentStep < 3) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitRegistration();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep -= 1;
                    // 返回上一步时重置 PIN 输入状态
                    _pin = '';
                    _confirmPin = '';
                    _pinConfirmed = false;
                  });
                }
              },
              steps: [
                Step(
                  title: Text('第 1 步：设置家长防卫锁', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  content: Column(
                    children: [
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
                            margin: EdgeInsets.symmetric(horizontal: 8.w),
                            width: 18.w,
                            height: 18.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? const Color(0xFF00A0E9) : Colors.grey.shade300,
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 20.h),
                      // 自定义九键数字键盘
                      PinKeypad(
                        onKeyPress: _onPinKeyPress,
                        onDelete: _onPinDelete,
                        keySize: 56,
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: Text('第 2 步：创建英雄档案', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  content: Column(
                    children: [
                      // 头像选择 (拍照 / 上传)
                      Center(
                        child: InkWell(
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
                      ),
                      SizedBox(height: 8.h),
                      Center(
                        child: Text(
                          '点击设置头像 (可拍照或上传)',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _childNameController,
                        onChanged: (_) => setState(() {}), // 头像占位实时跟随昵称
                        decoration: InputDecoration(
                          labelText: '英雄昵称 (例：小明)',
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
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: Text('第 3 步：选择防卫主题', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  content: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: RadioListTile<String>(
                      title: Text('光之守护 (奥特曼宇宙)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      subtitle: Text('包含光线攻击音效与怪兽打卡', style: TextStyle(fontSize: 14.sp)),
                      value: 'ultraman',
                      groupValue: _selectedTheme,
                      onChanged: (v) => setState(() => _selectedTheme = v!),
                      activeColor: const Color(0xFF00A0E9),
                    ),
                  ),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: Text('第 4 步：挑选任务与奖励', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  content: _buildPresetPicker(),
                  isActive: _currentStep >= 3,
                  state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 第 4 步：多选预设任务与奖励模板。
  Widget _buildPresetPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 任务模板 =====
        Text(
          '选择打卡任务（可多选，共 ${taskTemplates.length} 个模板）',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _selectedTaskIndexes.addAll(List.generate(taskTemplates.length, (i) => i));
              }),
              child: Text('全选', style: TextStyle(fontSize: 13.sp)),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedTaskIndexes.clear()),
              child: Text('清空', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // 不再用 maxHeight 限高：外层 SingleChildScrollView 统一滚动，
        // 列表 shrinkWrap 完整展开所有模板，避免内容被裁剪导致底部看不到。
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: taskTemplates.length,
            itemBuilder: (context, index) {
              final t = taskTemplates[index];
              final selected = _selectedTaskIndexes.contains(index);
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected,
                title: Text(t.title, style: TextStyle(fontSize: 14.sp)),
                subtitle: Text(
                  '${t.type == 'math' ? '数学题' : _typeLabel(t.type)} · ${t.rewardCoins}币/${t.rewardExp}EXP',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedTaskIndexes.add(index);
                  } else {
                    _selectedTaskIndexes.remove(index);
                  }
                }),
              );
            },
          ),
        ),
        SizedBox(height: 16.h),

        // ===== 奖励模板 =====
        Text(
          '选择奖励（可多选，共 ${rewardTemplates.length} 个模板）',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _selectedRewardIndexes.addAll(List.generate(rewardTemplates.length, (i) => i));
              }),
              child: Text('全选', style: TextStyle(fontSize: 13.sp)),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedRewardIndexes.clear()),
              child: Text('清空', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // 同样去掉 maxHeight，完整展开所有奖励模板。
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rewardTemplates.length,
            itemBuilder: (context, index) {
              final r = rewardTemplates[index];
              final selected = _selectedRewardIndexes.contains(index);
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected,
                title: Text(r.title, style: TextStyle(fontSize: 14.sp)),
                subtitle: Text(
                  '${r.costCoins} 币',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedRewardIndexes.add(index);
                  } else {
                    _selectedRewardIndexes.remove(index);
                  }
                }),
              );
            },
          ),
        ),

        SizedBox(height: 16.h),

        // ===== 桌面快捷方式（可选） =====
        Text(
          '桌面快捷方式（可选）',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4.h),
        Text(
          '把儿童专属入口放到手机桌面：可自定义图标（用儿童头像）和名字（用英雄昵称）。',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              SwitchListTile(
                dense: true,
                title: Text('使用儿童头像作为图标', style: TextStyle(fontSize: 14.sp)),
                subtitle: Text(
                  _avatarImage.isEmpty ? '尚未设置头像，将使用默认图标' : '已选择头像',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
                value: _shortcutUseAvatar,
                activeColor: const Color(0xFF00A0E9),
                onChanged: (v) => setState(() => _shortcutUseAvatar = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                dense: true,
                title: Text('使用英雄昵称作为名字', style: TextStyle(fontSize: 14.sp)),
                subtitle: Text(
                  '如「小明」→「小明英雄闯关冒险」',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
                value: _shortcutUseName,
                activeColor: const Color(0xFF00A0E9),
                onChanged: (v) => setState(() => _shortcutUseName = v),
              ),
              if (!_shortcutUseName) ...[
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: TextField(
                    controller: _shortcutNameController,
                    onChanged: (v) => _shortcutCustomName = v,
                    decoration: InputDecoration(
                      labelText: '自定义名字（默认：小朋友冒险计划）',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'daily':
        return '每日';
      case 'weekly':
        return '每周';
      case 'once':
        return '单次';
      case 'math':
        return '数学题';
      default:
        return type;
    }
  }
}