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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              // 限制最大宽度，平板横屏时内容居中不横向铺满；
              // 所有尺寸用普通逻辑像素（不用 .w/.sp/.r 缩放），
              // 避免横向平板上 screenutil 放大导致内容过高需滚动。
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 48, color: Color(0xFF00A0E9)),
                    const SizedBox(height: 12),
                    const Text(
                      '请输入宇宙警备队授权码',
                      style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '验证通过后本机将记住为家长设备，下次直接进入',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    // 密码圆点指示器
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _inputPin.length
                                ? const Color(0xFF00A0E9)
                                : Colors.grey.shade300,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // 自定义九键数字键盘 (固定像素，浅色主题，与其他 PIN 界面一致)
                    PinKeypad(
                      onKeyPress: _onKeyPress,
                      onDelete: _onDelete,
                      keySize: 56,
                      dark: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}