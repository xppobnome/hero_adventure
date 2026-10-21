import 'dart:io';

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
/// 绑定 WebDAV 且开启「启动时检查数据版本」后，每次启动都会通过 PROPFIND
/// 读取云端文件的最后修改时间（getlastmodified），与本机最近一次同步记录比较
/// （加 1 秒容差）：云端更新时弹窗询问是否「更新并合并数据」。
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

    // 远端文件的最后修改时间（WebDAV getlastmodified，坚果云原生支持）。
    final remoteModified = await syncRepo.fetchRemoteModified(
      url: url,
      username: user,
      password: pwd,
      directory: dir,
    );
    if (remoteModified == null) return null; // 云端无此文件

    final lastSynced = storage.getLastSyncedUploadAt();
    if (lastSynced.isNotEmpty) {
      final remote = _parseTime(remoteModified);
      final local = _parseTime(lastSynced);
      if (remote != null && local != null) {
        // 加 1 秒容差：避免系统时间微小差异导致误判。
        // 比较时统一用 UTC 时间戳，与坚果云返回的 GMT 基准对齐。
        if (remote.toUtc().difference(local.toUtc()).inSeconds.abs() <= 1) {
          return null; // 云端不新于本机（相同或更旧）
        }
      }
    } else {
      // 本机从未同步过，无法判断；默认视为有云端数据，提示一次。
      // 用户「更新并合并」或「暂不」后都会写入时间戳，之后不再重复提示。
    }

    return RemoteNewer(uploadAt: remoteModified);
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

  /// 解析时间字符串，支持：
  /// - ISO 8601（如 '2026-03-02T10:00:00Z'、'2026-03-02T10:00:00.000Z'）
  /// - RFC 1123（坚果云 getlastmodified 返回，如 'Thu, 21 Oct 2026 12:00:00 GMT'）
  ///
  /// 解析失败返回 null。返回的时间统一为 UTC 基准（ISO 带 Z 的已为 UTC；
  /// RFC 1123 用 HttpDate.parse 解析得到的也是 UTC）。
  static DateTime? _parseTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) 优先尝试 ISO 8601（带时区信息）。
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      // 带 Z / +08:00 等时区后缀时，tryParse 已正确换算；
      // 不带时区后缀（如本地生成的 toIso8601String()）则视为 UTC，
      // 与坚果云返回的 GMT 基准保持一致，避免本机时区影响比较。
      if (s.endsWith('Z') || s.contains('+') || s.contains(RegExp(r'-\d\d:\d\d$'))) {
        return iso;
      }
      return DateTime.utc(
        iso.year,
        iso.month,
        iso.day,
        iso.hour,
        iso.minute,
        iso.second,
        iso.millisecond,
      );
    }

    // 2) RFC 1123（坚果云等 WebDAV 服务的 getlastmodified 格式）。
    try {
      return HttpDate.parse(s); // 返回 UTC 时间
    } catch (_) {
      return null;
    }
  }

  /// 把时间格式化为「北京时间」显示（UTC+8）。
  static String _formatTime(String raw) {
    final t = _parseTime(raw);
    if (t == null) return raw.isEmpty ? '从未同步' : raw;
    // 统一转 UTC 再加 8 小时得到北京时间。
    final beijing = t.toUtc().add(const Duration(hours: 8));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${beijing.year}-${two(beijing.month)}-${two(beijing.day)} '
        '${two(beijing.hour)}:${two(beijing.minute)}（北京时间）';
  }
}

/// 云端数据较新的信息。
class RemoteNewer {
  const RemoteNewer({required this.uploadAt});

  /// 云端数据的上传日期时间（ISO 8601）。
  final String uploadAt;
}
