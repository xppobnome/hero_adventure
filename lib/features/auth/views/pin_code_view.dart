import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../domain/providers/family_provider.dart';
import '../../parent_console/views/parent_console_view.dart';

class PinCodeView extends ConsumerStatefulWidget {
  const PinCodeView({super.key});

  @override
  ConsumerState<PinCodeView> createState() => _PinCodeViewState();
}

class _PinCodeViewState extends ConsumerState<PinCodeView> {
  String _inputPin = '';

  void _onKeyPress(String key) {
    if (_inputPin.length < 4) {
      setState(() => _inputPin += key);
    }

    if (_inputPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_inputPin.isNotEmpty) {
      setState(() => _inputPin = _inputPin.substring(0, _inputPin.length - 1));
    }
  }

  void _verifyPin() {
    final family = ref.read(familyProfileProvider);
    final correctPin = family?.pinCode ?? '0000'; // 兜底处理

    if (_inputPin == correctPin) {
      // 登录成功：将本设备标记为「家长设备」，下次打开 App 直接进入家长控制台，
      // 无需再次输入 PIN。
      ref.read(deviceRoleProvider.notifier).state = 'parent';
      ref.read(storageProvider).saveDeviceRole('parent');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParentConsoleView()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('警报！防卫密码错误', style: TextStyle(fontSize: 14.sp)), backgroundColor: Colors.red),
      );
      setState(() => _inputPin = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.r),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 80.r, color: Colors.white),
                SizedBox(height: 20.h),
                Text(
                  '请输入宇宙警备队授权码',
                  style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  '验证通过后本机将记住为家长设备，下次直接进入',
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                ),
                SizedBox(height: 40.h),
                // 密码圆点指示器
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _inputPin.length ? Colors.blueAccent : Colors.grey.shade700,
                      ),
                    );
                  }),
                ),
                SizedBox(height: 40.h),
                // 自定义九键数字键盘 (深色主题)
                PinKeypad(
                  onKeyPress: _onKeyPress,
                  onDelete: _onDelete,
                  keySize: 68.w,
                  dark: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}