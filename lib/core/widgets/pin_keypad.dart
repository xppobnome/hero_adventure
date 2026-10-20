import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 自定义数字键盘 (银行密码式，不唤起系统输入法)。
///
/// 标准九宫格布局：
///   1 2 3
///   4 5 6
///   7 8 9
///   空 0 ⌫
/// 用 Column + Row 显式 3 列排布，避免 Wrap 自动换行导致的错乱，
/// 且在 AlertDialog / Stepper 等测量固有尺寸的容器里不会触发崩溃。
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;

  /// 单个按键的直径 (默认 64，适配平板可放大)。
  final double keySize;

  /// 数字键是否用深色主题 (家长 PIN 登录页用深色背景)。
  final bool dark;

  const PinKeypad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    this.keySize = 64,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    Widget key(Widget child, {VoidCallback? onTap, Color? color, double elevation = 0}) {
      return Material(
        color: color ?? (dark ? Colors.grey.shade800 : Colors.white),
        shape: const CircleBorder(),
        elevation: elevation,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: keySize,
            height: keySize,
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget digit(String number) {
      return key(
        Text(
          number,
          style: TextStyle(
            fontSize: keySize * 0.42,
            fontWeight: FontWeight.w600,
            color: dark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: dark ? 0 : 2,
        onTap: () => onKeyPress(number),
      );
    }

    Widget backspace() {
      return key(
        Icon(Icons.backspace, color: dark ? Colors.white70 : Colors.grey.shade700, size: keySize * 0.4),
        color: dark ? Colors.grey.shade700 : Colors.grey.shade200,
        onTap: onDelete,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pad(digit('1'), spacing),
          _pad(digit('2'), spacing),
          _pad(digit('3'), 0),
        ]),
        SizedBox(height: spacing),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pad(digit('4'), spacing),
          _pad(digit('5'), spacing),
          _pad(digit('6'), 0),
        ]),
        SizedBox(height: spacing),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pad(digit('7'), spacing),
          _pad(digit('8'), spacing),
          _pad(digit('9'), 0),
        ]),
        SizedBox(height: spacing),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pad(SizedBox(width: keySize, height: keySize), spacing),
          _pad(digit('0'), spacing),
          _pad(backspace(), 0),
        ]),
      ],
    );
  }

  Widget _pad(Widget child, double rightSpace) {
    return Padding(padding: EdgeInsets.only(right: rightSpace), child: child);
  }
}
