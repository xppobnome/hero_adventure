import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/local_backup.dart';
import '../../../data/repositories/sync_repo.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../auth/views/role_selection_view.dart';
import 'qr_sync_view.dart';

class SyncDashboardView extends ConsumerStatefulWidget {
  const SyncDashboardView({super.key});

  @override
  ConsumerState<SyncDashboardView> createState() => _SyncDashboardViewState();
}

class _SyncDashboardViewState extends ConsumerState<SyncDashboardView> {
  final _urlController = TextEditingController(
    text: 'https://dav.jianguoyun.com/dav/',
  );
  final _userController = TextEditingController();
  final _pwdController = TextEditingController();

  bool _isLoading = false;

  /// 导出全量数据快照到本地 JSON 文件。
  Future<void> _exportLocal() async {
    try {
      final path = await LocalBackup.exportToFile(ref.read(storageProvider));
      if (path == null) return; // 用户取消
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

  /// 从本地 JSON 文件导入并恢复全量数据。
  Future<void> _importLocal() async {
    try {
      final ok = await LocalBackup.importFromFile(ref.read(storageProvider));
      if (!ok) return; // 用户取消
      // 刷新所有 Provider 状态，让内存态与恢复后的本地数据对齐
      ref.invalidate(familyProfileProvider);
      ref.invalidate(taskProvider);
      ref.invalidate(rewardProvider);
      ref.invalidate(checkInProvider);
      ref.invalidate(exchangeProvider);
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

  // 修改 _performSync 方法中的恢复逻辑
  Future<void> _performSync(bool isBackup) async {
    setState(() => _isLoading = true);
    try {
      final syncRepo = SyncRepo(ref.read(storageProvider));
      if (isBackup) {
        await syncRepo.backupToWebDav(
          url: _urlController.text,
          username: _userController.text,
          password: _pwdController.text,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('云端备份成功！')));
      } else {
        await syncRepo.restoreFromWebDav(
          url: _urlController.text,
          username: _userController.text,
          password: _pwdController.text,
        );
        // 刷新所有 Provider 状态
        ref.invalidate(familyProfileProvider);
        ref.invalidate(taskProvider);
        ref.invalidate(rewardProvider);
        ref.invalidate(checkInProvider);
        ref.invalidate(exchangeProvider);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('数据恢复成功！')));

        // 【新增】：如果是在全新设备恢复数据，恢复完成后直接前往主页
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionView()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同步失败: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('数据时空穿梭机', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ① 面对面同步
                  _SectionCard(
                    icon: Icons.qr_code_2,
                    iconColor: Colors.blue,
                    title: '面对面同步',
                    subtitle: '无需网络，两台设备扫码互传',
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_2, size: 22),
                        label: const Text('二维码同步 (免流)'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          foregroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QrSyncView(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // ② 本地文件备份
                  _SectionCard(
                    icon: Icons.folder_outlined,
                    iconColor: Colors.green,
                    title: '本地文件备份',
                    subtitle: '导出 JSON 备份文件，或从文件导入恢复',
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 22),
                        label: const Text('导出到本地文件'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          foregroundColor: Colors.green,
                        ),
                        onPressed: _exportLocal,
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton.icon(
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 22,
                        ),
                        label: const Text('从本地文件导入'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _importLocal,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // ③ WebDAV 云端同步
                  _SectionCard(
                    icon: Icons.cloud_outlined,
                    iconColor: Colors.orange,
                    title: 'WebDAV 云端同步',
                    subtitle: '备份到坚果云等 WebDAV 服务',
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'WebDAV 地址',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: '账号',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _pwdController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '授权密码',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        ElevatedButton.icon(
                          icon: Icon(
                            Icons.cloud_upload,
                            size: 22.r,
                            color: Colors.white,
                          ),
                          label: Text(
                            '备份数据到云端',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          onPressed: () => _performSync(true),
                        ),
                        SizedBox(height: 16.h),
                        OutlinedButton.icon(
                          icon: Icon(Icons.cloud_download, size: 22.r),
                          label: Text(
                            '从云端恢复数据',
                            style: TextStyle(fontSize: 16.sp),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          onPressed: () => _performSync(false),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组卡片：统一的圆角卡片外观，带彩色图标标题 + 说明文字 + 内容区。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: iconColor, size: 26.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }
}
