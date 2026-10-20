import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../shared/settings/update_settings_cards.dart';
import '../../../domain/providers/theme_provider.dart';

/// 儿童端设置页。
///
/// 展示与应用更新 / 数据版本相关的通用设置（与家长端共用同一组件）。
class ChildSettingsView extends StatelessWidget {
  const ChildSettingsView({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(24.w),
          children: [
            Text(
              '更新与数据版本',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            const AppUpdateSettingsCard(),
            SizedBox(height: 16.h),
            const DataSyncSettingsCard(),
          ],
        ),
      ),
    );
  }
}
