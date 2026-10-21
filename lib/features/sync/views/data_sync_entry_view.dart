import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/local_backup.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/task_provider.dart';
import 'qr_sync_view.dart';
import 'sync_dashboard_view.dart';

/// 「数据同步与恢复」入口页：集中提供面对面传输、WebDAV 云端同步、
/// 本地文件备份三个入口。
///
/// 家长设置页与儿童设置页共用，避免多个入口在设置里重复堆叠。
class DataSyncEntryView extends ConsumerStatefulWidget {
  const DataSyncEntryView({super.key});

  @override
  ConsumerState<DataSyncEntryView> createState() => _DataSyncEntryViewState();
}

class _DataSyncEntryViewState extends ConsumerState<DataSyncEntryView> {
  /// 刷新所有业务 Provider，让内存态与恢复后的本地数据对齐。
  void _invalidateAllProviders() {
    ref.invalidate(familyProfileProvider);
    ref.invalidate(taskProvider);
    ref.invalidate(rewardProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(exchangeProvider);
  }

  Future<void> _exportToFile() async {
    try {
      final path = await LocalBackup.exportToFile(ref.read(storageProvider));
      if (path == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功：$path'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importFromFile() async {
    try {
      final ok = await LocalBackup.importFromFile(ref.read(storageProvider));
      if (!ok) return;
      _invalidateAllProviders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据导入成功！'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('数据同步与恢复', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            Text(
              '选择同步方式',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16.h),
            _entryCard(
              context,
              icon: Icons.wifi_tethering,
              color: Colors.blue,
              title: '面对面传输（局域网）',
              subtitle: '同一 WiFi 下扫码直传全部数据（含图片）',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrSyncView()),
              ),
            ),
            SizedBox(height: 16.h),
            _entryCard(
              context,
              icon: Icons.cloud_outlined,
              color: Colors.orange,
              title: 'WebDAV 云端同步',
              subtitle: '备份到坚果云等 WebDAV 服务，防丢失',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncDashboardView()),
              ),
            ),
            SizedBox(height: 16.h),
            _entryCard(
              context,
              icon: Icons.folder_outlined,
              color: Colors.green,
              title: '本地文件备份',
              subtitle: '导出 / 导入 .herobackup 备份文件（含图片）',
              onTap: _showLocalBackupDialog,
            ),
            SizedBox(height: 24.h),
            Text(
              '提示：面对面传输需两台设备连接同一 WiFi 或一台开启热点；'
              'WebDAV 同步需先配置坚果云等服务的账号信息。',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// 本地文件备份：弹出导出/导入选择。
  void _showLocalBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('本地文件备份', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _exportToFile();
            },
            child: Row(
              children: [
                Icon(Icons.file_upload_outlined, color: Colors.green, size: 24.r),
                SizedBox(width: 12.w),
                Text('导出到本地文件', style: TextStyle(fontSize: 16.sp)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _importFromFile();
            },
            child: Row(
              children: [
                Icon(Icons.file_download_outlined, color: Colors.green, size: 24.r),
                SizedBox(width: 12.w),
                Text('从本地文件导入', style: TextStyle(fontSize: 16.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        leading: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28.r),
        ),
        title: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13.sp)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
