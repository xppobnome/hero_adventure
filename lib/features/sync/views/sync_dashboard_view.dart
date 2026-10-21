import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/local_backup.dart';
import '../../../core/utils/url_opener.dart';
import '../../../data/repositories/local_storage_repo.dart';
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
  final _dirController = TextEditingController(
    text: LocalStorageRepo.defaultWebDavDir,
  );

  bool _isLoading = false;
  bool _obscurePwd = true; // 授权密码是否隐藏（小眼睛切换）

  @override
  void initState() {
    super.initState();
    // 回填已保存的 WebDAV 配置（启动时数据版本检查依赖此持久化配置）。
    final storage = ref.read(storageProvider);
    final (url, user, pwd, dir) = storage.getWebDavConfig();
    if (url.isNotEmpty) _urlController.text = url;
    if (user.isNotEmpty) _userController.text = user;
    if (pwd.isNotEmpty) _pwdController.text = pwd;
    if (dir.isNotEmpty) _dirController.text = dir;
  }

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
      final dir = _dirController.text.trim().isEmpty
          ? LocalStorageRepo.defaultWebDavDir
          : _dirController.text.trim();
      if (isBackup) {
        await syncRepo.backupToWebDav(
          url: _urlController.text,
          username: _userController.text,
          password: _pwdController.text,
          directory: dir,
        );
        // 持久化 WebDAV 配置：供启动时数据版本自动检查使用。
        await ref
            .read(storageProvider)
            .saveWebDavConfig(
              url: _urlController.text,
              username: _userController.text,
              password: _pwdController.text,
              directory: dir,
            );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('云端备份成功！')));
      } else {
        await syncRepo.restoreFromWebDav(
          url: _urlController.text,
          username: _userController.text,
          password: _pwdController.text,
          directory: dir,
        );
        // 持久化 WebDAV 配置（恢复时也保存，保证后续启动检查路径一致）。
        await ref
            .read(storageProvider)
            .saveWebDavConfig(
              url: _urlController.text,
              username: _userController.text,
              password: _pwdController.text,
              directory: dir,
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

        // 如果是在全新设备恢复数据，恢复完成后直接前往主页
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const RoleSelectionView()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      // 判断是否为账号/密码错误（401 未授权）。
      final msg = e.toString();
      final isAuthError = msg.contains('401') || msg.contains('403');
      if (isAuthError) {
        _showAuthErrorDialog();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
      print('同步失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 账号 / 密码错误提示弹窗：附「坚果云教程」按钮跳转帮助页。
  void _showAuthErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '账号或密码错误',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'WebDAV 登录失败，请检查坚果云账号与授权密码是否正确。\n\n'
          '提示：坚果云的 WebDAV 密码需要在「账户信息 → 安全选项 → 第三方应用管理」中单独设置，'
          '与登录密码不同。',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('坚果云教程'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A0E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              UrlOpener.open('https://help.jianguoyun.com/?p=2064', context: context);
            },
          ),
        ],
      ),
    );
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
                    title: '面对面传输（局域网）',
                    subtitle: '同一 WiFi 下，扫码直传全部数据（含图片）',
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.wifi_tethering, size: 22),
                        label: const Text('发起面对面传输'),
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
                    subtitle: '导出 .herobackup 备份文件（含图片），或从文件导入恢复',
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
                        obscureText: _obscurePwd,
                        decoration: InputDecoration(
                          labelText: '授权密码',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePwd
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 22,
                            ),
                            tooltip: _obscurePwd ? '显示密码' : '隐藏密码',
                            onPressed: () {
                              setState(() => _obscurePwd = !_obscurePwd);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: _dirController,
                        decoration: InputDecoration(
                          labelText: '存储目录',
                          hintText: '默认 /HeroAdventure',
                          helperText: '云端存储数据的文件夹路径',
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
