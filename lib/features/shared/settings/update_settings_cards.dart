import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/data_sync_checker.dart';
import '../../../core/utils/update_service.dart';
import '../../../domain/providers/family_provider.dart';

/// 「应用更新」设置卡片：自动更新开关 + 检查更新按钮。
///
/// 家长设置页与儿童设置页共用。
class AppUpdateSettingsCard extends ConsumerStatefulWidget {
  const AppUpdateSettingsCard({super.key});

  @override
  ConsumerState<AppUpdateSettingsCard> createState() =>
      _AppUpdateSettingsCardState();
}

class _AppUpdateSettingsCardState extends ConsumerState<AppUpdateSettingsCard> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final autoCheck = storage.getUpdateAutoCheck();
    final permanentlyIgnored = storage.getUpdatePermanentIgnored();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.system_update, color: Colors.blue, size: 24.r),
            ),
            title: Text(
              '自动检查更新',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              permanentlyIgnored ? '已设置永久忽略更新' : '开启后每次启动都会检查新版本',
              style: TextStyle(fontSize: 14.sp),
            ),
            value: autoCheck,
            activeColor: const Color(0xFF00A0E9),
            onChanged: permanentlyIgnored
                ? null // 永久忽略时禁用开关，需先取消永久忽略
                : (v) async {
                    await storage.setUpdateAutoCheck(v);
                    if (mounted) setState(() {});
                  },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, color: Colors.green, size: 24.r),
            ),
            title: Text(
              '检查更新',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('手动检查是否有新版本', style: TextStyle(fontSize: 14.sp)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => UpdateService.checkManually(context, storage),
          ),
        ],
      ),
    );
  }
}

/// 「数据版本检查」设置卡片：仅在已绑定 WebDAV 时显示。
///
/// 包含「启动时检查数据版本并合并」开关 + 「检查数据版本」按钮。
class DataSyncSettingsCard extends ConsumerStatefulWidget {
  const DataSyncSettingsCard({super.key});

  @override
  ConsumerState<DataSyncSettingsCard> createState() =>
      _DataSyncSettingsCardState();
}

class _DataSyncSettingsCardState extends ConsumerState<DataSyncSettingsCard> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);

    // 未绑定 WebDAV 时不显示该设置项。
    if (!storage.hasWebDavConfig()) return const SizedBox.shrink();

    final autoCheck = storage.getDataSyncAutoCheck();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_sync, color: Colors.orange, size: 24.r),
            ),
            title: Text(
              '启动时检查数据版本',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '每次启动检查云端数据是否更新并提示合并',
              style: TextStyle(fontSize: 14.sp),
            ),
            value: autoCheck,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setDataSyncAutoCheck(v);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fact_check, color: Colors.teal, size: 24.r),
            ),
            title: Text(
              '检查数据版本',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('手动检查云端是否有更新的数据', style: TextStyle(fontSize: 14.sp)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => DataSyncChecker.checkManually(context, storage),
          ),
        ],
      ),
    );
  }
}
