import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'pin_keypad.dart';

/// 统一的 PIN 输入对话框（自定义数字键盘，不唤起系统输入法）。
///
/// 供「儿童安全锁解锁」「修改防卫密码」等场景复用，保证所有 PIN 输入
/// 界面的键盘样式、圆点指示器、错误提示完全一致。
///
/// [title] 对话框标题；[subtitle] 说明文字；
/// [onSubmit] 收到完整 4 位 PIN 时的回调，返回 true 表示验证通过并关闭，
/// 返回 false 表示验证失败（自动清空重输）。
class PinInputDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function(String pin) onSubmit;
  final bool dark;

  const PinInputDialog({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle = '',
    this.dark = false,
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog> {
  String _pin = '';
  String? _errorText;
  bool _verifying = false;

  Future<void> _onKey(String key) async {
    if (_verifying) return;
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _errorText = null;
    });
    if (_pin.length == 4) {
      await _submit();
    }
  }

  void _onDelete() {
    if (_verifying) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorText = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _verifying = true);
    final ok = await widget.onSubmit(_pin);
    if (!mounted) return;
    if (ok) {
      // 关键：必须把验证结果 (true) 作为返回值 pop 出去，
      // 否则 showDialog<bool> 的 Future 结果会是 null，调用方
      // 无法得知验证通过，导致「解除绑定后不返回」的 bug。
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _pin = '';
        _errorText = '密码错误，请重试';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return AlertDialog(
      backgroundColor: dark ? Colors.grey.shade900 : null,
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: dark ? Colors.white : null,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle.isNotEmpty) ...[
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 13.sp, color: dark ? Colors.white54 : Colors.grey.shade600),
            ),
            SizedBox(height: 8.h),
          ],
          if (_errorText != null) ...[
            Text(
              _errorText!,
              style: TextStyle(fontSize: 13.sp, color: Colors.red),
            ),
            SizedBox(height: 8.h),
          ],
          // 圆点指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 6.w),
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length
                      ? (dark ? Colors.blueAccent : const Color(0xFF00A0E9))
                      : (dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              );
            }),
          ),
          SizedBox(height: 16.h),
          PinKeypad(
            onKeyPress: _onKey,
            onDelete: _onDelete,
            keySize: 56,
            dark: dark,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
