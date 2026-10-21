import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/providers/family_provider.dart';

/// 「界面样式」设置卡片：展示当前生效的界面适配模式，点击弹出对话框选择。
///
/// - 自动（默认）：根据设备型号/屏幕尺寸自动判断手机或平板版式。
/// - 手机模式：强制按手机版式缩放。
/// - 平板模式：强制按平板版式缩放。
///
/// 家长设置页与儿童设置页共用。修改后需重启应用生效（缩放基准在启动时确定）。
class UiModeSettingsCard extends ConsumerStatefulWidget {
  const UiModeSettingsCard({super.key});

  @override
  ConsumerState<UiModeSettingsCard> createState() => _UiModeSettingsCardState();
}

class _UiModeSettingsCardState extends ConsumerState<UiModeSettingsCard> {
  String get _current => ref.read(storageProvider).getUiMode();

  /// 读取物理逻辑尺寸的短边（逻辑像素），拿不到时返回 null。
  double? get _physicalShortSide {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final view = views.first;
    final physical = view.physicalSize;
    final ratio = view.devicePixelRatio;
    final w = physical.width / ratio;
    final h = physical.height / ratio;
    return w < h ? w : h;
  }

  String _label(String mode) {
    switch (mode) {
      case 'phone':
        return '手机模式';
      case 'tablet':
        return '平板模式';
      default:
        // 「自动」：括号内展示按当前物理尺寸实际解析出的手机 / 平板模式，
        // 与 main.dart 的 _resolveDesignSize 判定逻辑一致（短边 >= 600dp 视为平板）。
        final shortSide = _physicalShortSide;
        final isTablet = shortSide != null && shortSide >= 600;
        return isTablet ? '自动（平板模式）' : '自动（手机模式）';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.devices, color: Colors.purple, size: 24.r),
        ),
        title: Text(
          '界面样式',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '当前：${_label(_current)}',
          style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showPicker,
      ),
    );
  }

  Future<void> _showPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择界面样式', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        children: [
          for (final (value, label, desc) in const [
            ('auto', '自动（推荐）', '根据设备型号自动适配手机 / 平板'),
            ('phone', '手机模式', '按手机版式缩放，内容紧凑'),
            ('tablet', '平板模式', '按平板版式缩放，内容舒展'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, value),
              child: Row(
                children: [
                  Icon(
                    _current == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _current == value ? const Color(0xFF00A0E9) : Colors.grey,
                    size: 22.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 16.sp)),
                        Text(desc, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null || selected == _current) return;
    await ref.read(storageProvider).setUiMode(selected);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('界面样式已保存，重启应用后生效')),
    );
  }
}
