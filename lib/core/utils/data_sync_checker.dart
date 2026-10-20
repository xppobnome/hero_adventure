import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/repositories/local_storage_repo.dart';
import '../../data/repositories/sync_repo.dart';
import '../../domain/providers/check_in_provider.dart';
import '../../domain/providers/exchange_provider.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/reward_provider.dart';
import '../../domain/providers/task_provider.dart';

/// WebDAV 云端数据版本检查服务。
///
/// 绑定 WebDAV 且开启「启动时检查数据版本」后，每次启动都会拉取云端
/// 快照的 uploadedAt（上传日期时间），与本机最近一次同步记录比较：
/// 云端更新时弹窗询问是否「更新并合并数据」。
class DataSyncChecker {
  DataSyncChecker._();

  /// 启动时的自动检查入口。
  static Future<void> checkOnStartup(
    BuildContext context,
    LocalStorageRepo storage,
  ) async {
    if (!storage.hasWebDavConfig()) return; // 未绑定 WebDAV
    if (!storage.getDataSyncAutoCheck()) return; // 用户关闭了自动检查

    try {
      final newer = await _findNewerRemote(storage);
      if (newer == null) return;
      if (!context.mounted) return;
      await showSyncPromptDialog(context, storage, newer);
    } catch (_) {
      // 启动时静默失败，不打扰用户。
    }
  }

  /// 手动「检查数据版本」按钮入口：显示检查过程与结果反馈。
  static Future<void> checkManually(
    BuildContext context,
    LocalStorageRepo storage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!storage.hasWebDavConfig()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('尚未绑定 WebDAV，请先在「WebDAV 同步与备份」中配置')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    RemoteNewer? newer;
    Object? error;
    try {
      newer = await _findNewerRemote(storage);
    } catch (e) {
      error = e;
    }
    // 关闭 loading 弹窗（它是当前唯一打开的 dialog）。
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('检查数据版本失败：$error'), backgroundColor: Colors.red),
      );
      return;
    }
    if (newer == null) {
      messenger.showSnackBar(const SnackBar(content: Text('本地数据已是最新 ✓')));
      return;
    }
    await showSyncPromptDialog(context, storage, newer);
  }

  /// 返回云端较新的信息；云端不比本机新（或无时间戳）时返回 null。
  static Future<RemoteNewer?> _findNewerRemote(LocalStorageRepo storage) async {
    final (url, user, pwd, dir) = storage.getWebDavConfig();
    final syncRepo = SyncRepo(storage);

    final remoteUploadAt = await syncRepo.fetchRemoteUploadAt(
      url: url,
      username: user,
      password: pwd,
      directory: dir,
    );
    if (remoteUploadAt == null) return null; // 云端无版本信息

    final lastSynced = storage.getLastSyncedUploadAt();
    if (lastSynced.isNotEmpty) {
      // 云端时间戳与本机记录的一致（或更旧），说明无新数据。
      if (DateTime.tryParse(
            remoteUploadAt,
          )!.isBefore(DateTime.tryParse(lastSynced)!) ||
          remoteUploadAt == lastSynced) {
        return null;
      }
    } else if (lastSynced.isEmpty) {
      // 本机从未同步过，无法判断；默认视为有云端数据，提示一次。
      // 用户「更新并合并」或「暂不」后都会写入时间戳，之后不再重复提示。
    }

    return RemoteNewer(uploadAt: remoteUploadAt);
  }

  /// 版本提示弹窗：展示本机与云端的数据时间，提供「更新并合并」/「暂不更新」。
  static Future<void> showSyncPromptDialog(
    BuildContext context,
    LocalStorageRepo storage,
    RemoteNewer newer,
  ) {
    final remoteTime = _formatTime(newer.uploadAt);
    final localTime = _formatTime(storage.getLastSyncedUploadAt());

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_sync, color: const Color(0xFF00A0E9), size: 26.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '发现更新的云端数据',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('云端数据时间：$remoteTime', style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 6.h),
            Text(
              localTime.isEmpty ? '本机数据时间：从未同步' : '本机数据时间：$localTime',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              '更新将把云端数据合并到本机（覆盖本机的档案、任务、奖励、打卡与兑换记录）。',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // 暂不更新：只记录时间戳，下次不再提示同一版本。
          TextButton(
            onPressed: () async {
              await storage.setLastSyncedUploadAt(newer.uploadAt);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              '暂不更新',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey),
            ),
          ),
          // 更新并合并数据
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A0E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _mergeRemoteData(ctx, storage, newer.uploadAt),
            child: Text('更新并合并数据', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  static Future<void> _mergeRemoteData(
    BuildContext ctx,
    LocalStorageRepo storage,
    String uploadAt,
  ) async {
    final messenger = ScaffoldMessenger.of(ctx);
    try {
      final (url, user, pwd, dir) = storage.getWebDavConfig();
      final syncRepo = SyncRepo(storage);
      final snapshot = await syncRepo.fetchRemoteSnapshot(
        url: url,
        username: user,
        password: pwd,
        directory: dir,
      );
      await storage.restoreSnapshot(snapshot);
      await storage.setLastSyncedUploadAt(uploadAt);

      if (ctx.mounted) Navigator.pop(ctx);

      // 刷新所有 Provider，让内存态与合并后的数据对齐。
      // 通过读取 context 上方的 ProviderScope 完成（弹窗仍在树内）。
      final container = ProviderScope.containerOf(ctx, listen: false);
      container.invalidate(familyProfileProvider);
      container.invalidate(taskProvider);
      container.invalidate(rewardProvider);
      container.invalidate(checkInProvider);
      container.invalidate(exchangeProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('数据更新合并完成！'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('合并失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  static String _formatTime(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso.isEmpty ? '从未同步' : iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// 云端数据较新的信息。
class RemoteNewer {
  const RemoteNewer({required this.uploadAt});

  /// 云端数据的上传日期时间（ISO 8601）。
  final String uploadAt;
}
