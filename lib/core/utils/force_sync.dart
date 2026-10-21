import 'package:flutter/foundation.dart';

import '../../data/repositories/local_storage_repo.dart';
import '../../data/repositories/sync_repo.dart';

/// 「变更时强制同步」辅助工具。
///
/// 当用户开启「变更时强制同步」开关且已绑定 WebDAV 时，在打卡、兑换、
/// 审核通过等重要数据变更发生后，把最新数据静默备份到云端。
///
/// 设计为独立工具类，避免 LocalStorageRepo 与 SyncRepo 之间产生循环依赖。
class ForceSyncHelper {
  ForceSyncHelper._();

  /// 若满足「强制同步开关开启 + 已绑定 WebDAV」条件，则异步上传。
  /// 静默执行：成功/失败均不打扰用户（失败仅打日志）。
  static Future<void> maybeSync(LocalStorageRepo storage) async {
    try {
      if (!storage.getForceSync()) return;
      if (!storage.hasWebDavConfig()) return;

      final (url, user, pwd, dir) = storage.getWebDavConfig();
      if (url.isEmpty) return;

      final syncRepo = SyncRepo(storage);
      await syncRepo.backupToWebDav(
        url: url,
        username: user,
        password: pwd,
        directory: dir,
      );
      debugPrint('[强制同步] 变更后已备份最新数据到 WebDAV');
    } catch (e) {
      debugPrint('[强制同步] 上传失败：$e');
    }
  }
}
