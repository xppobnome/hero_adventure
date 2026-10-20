import 'dart:convert';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'local_storage_repo.dart';

class SyncRepo {
  final LocalStorageRepo _localStorage;

  /// WebDAV 上的数据快照文件路径。
  static const String remoteDataPath = '/hero_data.json';

  SyncRepo(this._localStorage);

  webdav.Client _getWebDavClient(String url, String username, String password) {
    return webdav.newClient(url, user: username, password: password);
  }

  // 备份全量数据到 WebDAV。
  // 快照中写入 uploadedAt 字段（上传日期时间），供启动时判断云端数据是否为最新版。
  Future<void> backupToWebDav({
    required String url,
    required String username,
    required String password,
  }) async {
    final client = _getWebDavClient(url, username, password);

    final snapshot = _localStorage.buildSnapshot();
    // 记录本次上传的日期时间，作为数据版本判断依据。
    final uploadedAt = DateTime.now().toIso8601String();
    snapshot['uploadedAt'] = uploadedAt;

    final jsonString = jsonEncode(snapshot);
    final bytesData = utf8.encode(jsonString);

    await client.write(remoteDataPath, bytesData);

    // 上传成功后，本机记录最近一次同步的云端时间戳，
    // 之后启动检查时以此判断云端是否出现了更新的数据。
    await _localStorage.setLastSyncedUploadAt(uploadedAt);
  }

  // 从 WebDAV 恢复全量数据
  Future<void> restoreFromWebDav({
    required String url,
    required String username,
    required String password,
  }) async {
    final snapshot = await fetchRemoteSnapshot(
      url: url,
      username: username,
      password: password,
    );

    await _localStorage.restoreSnapshot(snapshot);

    // 恢复后记录云端时间戳，避免启动检查时重复提示。
    final uploadedAt = snapshot['uploadedAt'] as String?;
    if (uploadedAt != null) {
      await _localStorage.setLastSyncedUploadAt(uploadedAt);
    }
  }

  /// 拉取云端快照（不写入本地）。
  ///
  /// 返回快照 Map；其中 'uploadedAt' 字段为云端数据的上传日期时间。
  Future<Map<String, dynamic>> fetchRemoteSnapshot({
    required String url,
    required String username,
    required String password,
  }) async {
    final client = _getWebDavClient(url, username, password);

    final responseBytes = await client.read(remoteDataPath);
    final jsonString = utf8.decode(responseBytes);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// 读取云端数据版本（上传日期时间）。
  ///
  /// 云端无数据或无 uploadedAt 字段时返回 null。
  Future<String?> fetchRemoteUploadAt({
    required String url,
    required String username,
    required String password,
  }) async {
    final snapshot = await fetchRemoteSnapshot(
      url: url,
      username: username,
      password: password,
    );
    return snapshot['uploadedAt'] as String?;
  }
}
