import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/avatar_picker.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../data/models/child_profile.dart';
import '../../../data/models/family_profile.dart';
import '../../../domain/providers/family_provider.dart';
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

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
      );
    }
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
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 600.w),
            child: Stepper(
              type: StepperType.vertical,
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
                            _currentStep == 2
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

                if (_currentStep < 2) {
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}