import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../shared/settings/update_settings_cards.dart';
import '../../shared/settings/ui_mode_settings_card.dart';
import '../../sync/views/data_sync_entry_view.dart';
import '../../../domain/providers/theme_provider.dart';

/// 儿童端设置页。
///
/// 展示与应用更新 / 数据版本 / 界面样式相关的通用设置，并提供
/// 「数据同步与恢复」入口（与家长端共用同一组件）。
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
              '数据同步与恢复',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sync_alt, color: Colors.blue, size: 24.r),
                ),
                title: Text(
                  '数据同步与恢复',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '面对面传输 / WebDAV 云端备份与恢复',
                  style: TextStyle(fontSize: 13.sp),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DataSyncEntryView()),
                  );
                },
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '界面样式',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            const UiModeSettingsCard(),
            SizedBox(height: 24.h),
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
