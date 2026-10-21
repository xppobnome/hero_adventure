import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/providers/family_provider.dart';

/// 「菜单栏文字」设置卡片：控制家长控制台底部/侧边菜单栏是否展示文字标签。
class NavLabelSettingsCard extends ConsumerWidget {
  const NavLabelSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageProvider);
    final show = ref.watch(showNavLabelsProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: SwitchListTile(
        secondary: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.label_outline, color: Colors.indigo, size: 24.r),
        ),
        title: Text(
          '菜单栏文字标签',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '展示家长控制台底部菜单栏的文字说明',
          style: TextStyle(fontSize: 13.sp),
        ),
        value: show,
        activeColor: const Color(0xFF00A0E9),
        onChanged: (v) async {
          await storage.setShowNavLabels(v);
          ref.read(showNavLabelsProvider.notifier).state = v;
        },
      ),
    );
  }
}
