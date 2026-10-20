import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_storage_repo.dart';

/// WebDAV 云端同步仓库。
///
/// 直接用 [http] 包实现 WebDAV 的 PUT（上传）/ GET（下载），
/// 替代 webdav_client 库——该库在上传时用 Dio Stream 且未设置 content-type，
/// 会触发 Dio 的 `_MultiStream cannot be used to imply a default content-type` 报错。
class SyncRepo {
  final LocalStorageRepo _localStorage;

  /// 云端数据快照的文件名（拼接在用户配置的目录路径下）。
  static const String remoteFileName = 'hero_data.json';

  SyncRepo(this._localStorage);

  /// 拼接完整的远端文件路径：目录路径（如 /HeroAdventure）+ 文件名。
  static String _remoteFilePath(String dir) {
    var d = dir.trim();
    if (d.isEmpty) d = '/';
    if (!d.startsWith('/')) d = '/$d';
    if (!d.endsWith('/')) d = '$d/';
    return '$d$remoteFileName';
  }

  /// 组装带 Basic Auth 的完整 URL。
  static Uri _buildUri(
    String url,
    String dir,
    String username,
    String password,
  ) {
    var base = url.trim();
    if (!base.endsWith('/')) base = '$base/';
    // 去掉末尾多余的斜杠，避免 //。
    final filePath = _remoteFilePath(dir);
    final fullPath = '${base.replaceFirst(RegExp(r'/+$'), '')}$filePath';

    final uri = Uri.parse(fullPath);
    return uri.replace(
      userInfo: username.isEmpty ? null : '$username:$password',
    );
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json; charset=utf-8',
  };

  // 备份全量数据到 WebDAV。
  // 快照中写入 uploadedAt 字段（上传日期时间），供启动时判断云端数据是否为最新版。
  Future<void> backupToWebDav({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final snapshot = _localStorage.buildSnapshot();
    // 记录本次上传的日期时间，作为数据版本判断依据。
    final uploadedAt = DateTime.now().toIso8601String();
    snapshot['uploadedAt'] = uploadedAt;

    final jsonString = jsonEncode(snapshot);
    final bytesData = utf8.encode(jsonString);

    final uri = _buildUri(url, directory, username, password);
    final resp = await http
        .put(uri, headers: _headers(), body: bytesData)
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      // 上传成功后，本机记录最近一次同步的云端时间戳。
      await _localStorage.setLastSyncedUploadAt(uploadedAt);
      return;
    }
    throw Exception('WebDAV 上传失败：HTTP ${resp.statusCode} ${resp.body}');
  }

  // 从 WebDAV 恢复全量数据
  Future<void> restoreFromWebDav({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final snapshot = await fetchRemoteSnapshot(
      url: url,
      username: username,
      password: password,
      directory: directory,
    );

    await _localStorage.restoreSnapshot(snapshot);

    // 恢复后记录云端时间戳，避免启动检查时重复提示。
    final uploadedAt = snapshot['uploadedAt'] as String?;
    if (uploadedAt != null) {
      await _localStorage.setLastSyncedUploadAt(uploadedAt);
    }
  }

  /// 拉取云端快照（不写入本地）。
  Future<Map<String, dynamic>> fetchRemoteSnapshot({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final uri = _buildUri(url, directory, username, password);
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('WebDAV 读取失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// 读取云端数据版本（上传日期时间）。
  ///
  /// 云端无数据或无 uploadedAt 字段时返回 null。
  Future<String?> fetchRemoteUploadAt({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final snapshot = await fetchRemoteSnapshot(
      url: url,
      username: username,
      password: password,
      directory: directory,
    );
    return snapshot['uploadedAt'] as String?;
  }
}
