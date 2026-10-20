import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/pin_keypad.dart';
import '../../../../domain/providers/family_provider.dart';
import '../../../shared/settings/update_settings_cards.dart';
import '../../../sync/views/sync_dashboard_view.dart';
import '../../../sync/views/qr_sync_view.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  // 修改密码的弹窗逻辑 (改用自定义数字键盘，不唤起系统输入法)
  void _showChangePinDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPin,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _ChangePinDialog(
        currentPin: currentPin,
        onConfirm: (newPin) {
          ref.read(familyProfileProvider.notifier).updatePin(newPin);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProfileProvider);
    if (family == null) return const SizedBox.shrink();

    return ListView(
      padding: EdgeInsets.all(24.w),
      children: [
        // ====== 视觉与体验 ======
        Text(
          '视觉与体验',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: Text(
                  '光之守护 (奥特曼宇宙)',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('当前生效的主题', style: TextStyle(fontSize: 14.sp)),
                value: 'ultraman',
                groupValue: family.currentTheme,
                onChanged: (v) {
                  ref.read(familyProfileProvider.notifier).updateTheme(v!);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('主题已切换为：光之守护')));
                },
                activeColor: const Color(0xFF00A0E9),
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: Text(
                  '机甲战士 (Mecha)',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                ),
                subtitle: Text(
                  '敬请期待',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
                value: 'mecha',
                groupValue: family.currentTheme,
                onChanged: null, // 禁用
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: Text(
                  '魔法学院 (Magic)',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                ),
                subtitle: Text(
                  '敬请期待',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
                value: 'magic',
                groupValue: family.currentTheme,
                onChanged: null, // 禁用
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        // ====== 应用更新与数据版本 ======
        Text(
          '更新与数据版本',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        const AppUpdateSettingsCard(),
        SizedBox(height: 16.h),
        const DataSyncSettingsCard(),

        SizedBox(height: 40.h),

        // ====== 数据与安全 ======
        Text(
          '数据与安全',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_2, color: Colors.blue, size: 24.r),
                ),
                title: Text(
                  '面对面传输（局域网）',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '同一 WiFi 下面对面传输数据',
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrSyncView()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_sync, color: Colors.blue, size: 24.r),
                ),
                title: Text(
                  'WebDAV 同步与备份',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '连接家庭 NAS 或坚果云防丢失',
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SyncDashboardView(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security, color: Colors.red, size: 24.r),
                ),
                title: Text(
                  '修改防卫密码 (PIN)',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '用于进入控制台时的身份验证',
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showChangePinDialog(context, ref, family.pinCode),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phonelink_erase,
                    color: Colors.orange,
                    size: 24.r,
                  ),
                ),
                title: Text(
                  '解除家长设备绑定',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '解除后本机下次打开将回到终端身份选择',
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showUnbindDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 解除家长设备绑定
  void _showUnbindDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '解除家长设备绑定',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '解除后，本机下次打开将回到「终端身份识别」界面，需要重新选择身份或输入 PIN。',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(deviceRoleProvider.notifier).state = 'unbound';
              ref.read(storageProvider).saveDeviceRole('unbound');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已解除家长设备绑定')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认解除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// 修改防卫密码弹窗：使用自定义数字键盘，不唤起系统输入法。
///
/// 分三阶段：输入旧 PIN → 输入新 PIN → 再次确认新 PIN，
/// 每个阶段用圆点指示器 + 3x4 数字键盘，全程无 TextField。
class _ChangePinDialog extends StatefulWidget {
  final String currentPin;
  final void Function(String newPin) onConfirm;

  const _ChangePinDialog({required this.currentPin, required this.onConfirm});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  // 阶段：0=输旧PIN，1=输新PIN，2=确认新PIN
  int _stage = 0;
  String _oldPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _errorText;

  String get _currentInput {
    switch (_stage) {
      case 0:
        return _oldPin;
      case 1:
        return _newPin;
      default:
        return _confirmPin;
    }
  }

  String get _stageTitle {
    switch (_stage) {
      case 0:
        return '请输入旧 PIN 码';
      case 1:
        return '请输入新 PIN 码';
      default:
        return '请再次输入新 PIN 码';
    }
  }

  void _onKeyPress(String key) {
    if (_currentInput.length >= 4) return;
    setState(() {
      _errorText = null;
      switch (_stage) {
        case 0:
          _oldPin += key;
          break;
        case 1:
          _newPin += key;
          break;
        default:
          _confirmPin += key;
          break;
      }
    });
    // 输满 4 位自动进入下一步判定
    if (_currentInput.length == 4) {
      _advance();
    }
  }

  void _onDelete() {
    setState(() {
      _errorText = null;
      switch (_stage) {
        case 0:
          if (_oldPin.isNotEmpty)
            _oldPin = _oldPin.substring(0, _oldPin.length - 1);
          break;
        case 1:
          if (_newPin.isNotEmpty)
            _newPin = _newPin.substring(0, _newPin.length - 1);
          break;
        default:
          if (_confirmPin.isNotEmpty)
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          break;
      }
    });
  }

  void _advance() {
    if (_stage == 0) {
      // 校验旧 PIN
      if (_oldPin != widget.currentPin) {
        setState(() {
          _errorText = '旧密码不正确';
          _oldPin = '';
        });
        return;
      }
      setState(() => _stage = 1);
    } else if (_stage == 1) {
      setState(() => _stage = 2);
    } else {
      // 确认新 PIN
      if (_confirmPin != _newPin) {
        setState(() {
          _errorText = '两次新密码不一致，请重试';
          _newPin = '';
          _confirmPin = '';
          _stage = 1;
        });
        return;
      }
      // 修改成功
      widget.onConfirm(_newPin);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('防卫密码修改成功！')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '修改防卫密码',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _stageTitle,
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
          ),
          if (_errorText != null) ...[
            SizedBox(height: 8.h),
            Text(
              _errorText!,
              style: TextStyle(fontSize: 13.sp, color: Colors.red),
            ),
          ],
          SizedBox(height: 16.h),
          // 圆点指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                width: 16.w,
                height: 16.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _currentInput.length
                      ? const Color(0xFF00A0E9)
                      : Colors.grey.shade300,
                  border: Border.all(color: Colors.grey.shade400),
                ),
              );
            }),
          ),
          SizedBox(height: 16.h),
          // 自定义数字键盘 (3x4，Wrap 布局避免固有尺寸断言)
          PinKeypad(onKeyPress: _onKeyPress, onDelete: _onDelete),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
