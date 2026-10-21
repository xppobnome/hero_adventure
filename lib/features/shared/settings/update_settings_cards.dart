import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/data_sync_checker.dart';
import '../../../core/utils/update_service.dart';
import '../../../data/repositories/local_storage_repo.dart';
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
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_download, color: Colors.purple, size: 24.r),
            ),
            title: Text(
              '更新源',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '当前：${UpdateService.sourceLabels[storage.getUpdateSource()] ?? 'GitHub'}',
              style: TextStyle(fontSize: 14.sp),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showSourcePicker(context, storage),
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
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download, color: Colors.orange, size: 24.r),
            ),
            title: Text(
              '网盘下载',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('前往蓝奏云下载最新安装包', style: TextStyle(fontSize: 14.sp)),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => UpdateService.openNetdisk(context),
          ),
        ],
      ),
    );
  }

  /// 更新源选择弹窗：GitHub / Gitee。
  Future<void> _showSourcePicker(
    BuildContext context,
    LocalStorageRepo storage,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          '选择更新源',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        children: [
          for (final source in const [
            UpdateService.sourceGithub,
            UpdateService.sourceGitee,
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, source),
              child: Row(
                children: [
                  Icon(
                    storage.getUpdateSource() == source
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: storage.getUpdateSource() == source
                        ? const Color(0xFF00A0E9)
                        : Colors.grey,
                    size: 22.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UpdateService.sourceLabels[source] ?? source,
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        Text(
                          _sourceDesc(source),
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null || selected == storage.getUpdateSource()) return;

    await storage.setUpdateSource(selected);
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '更新源已切换为 ${UpdateService.sourceLabels[selected]}',
        ),
      ),
    );
  }

  String _sourceDesc(String source) {
    switch (source) {
      case UpdateService.sourceGithub:
        return 'GitHub Releases（国际访问）';
      case UpdateService.sourceGitee:
        return 'Gitee Releases（国内加速）';
      default:
        return '';
    }
  }
}

/// 「数据版本检查与自动同步」设置卡片：仅在已绑定 WebDAV 时显示。
///
/// 统一在一个分组内，顺序为：
/// 手动检查数据版本 → 退出前上传数据 → 强制同步开关 → 启动时检查数据版本。
/// 家长设置页与儿童设置页共用，保证两侧内容与选中状态一致。
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
    final uploadOnExit = storage.getUploadOnExit();
    final forceSync = storage.getForceSync();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          // 1. 手动检查数据版本
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
              '手动检查数据版本',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('手动检查云端是否有更新的数据', style: TextStyle(fontSize: 14.sp)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => DataSyncChecker.checkManually(context, storage),
          ),
          const Divider(height: 1),
          // 2. 退出前上传数据
          SwitchListTile(
            secondary: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload, color: Colors.blue, size: 24.r),
            ),
            title: Text(
              '退出前上传数据',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '退出应用时自动把最新数据备份到云端（保持云端为最新版）',
              style: TextStyle(fontSize: 14.sp),
            ),
            value: uploadOnExit,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setUploadOnExit(v);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          // 3. 强制同步开关
          SwitchListTile(
            secondary: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sync_lock, color: Colors.purple, size: 24.r),
            ),
            title: Text(
              '变更时强制同步',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '打卡、兑换奖励、审核通过等重要变更时自动上传到云端',
              style: TextStyle(fontSize: 14.sp),
            ),
            value: forceSync,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setForceSync(v);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          // 4. 启动时检查数据版本
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
        ],
      ),
    );
  }
}
