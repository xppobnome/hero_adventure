import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/backup_pack.dart';
import 'local_storage_repo.dart';

/// WebDAV 云端同步仓库。
///
/// 直接用 [http] 包实现 WebDAV 的 PUT（上传）/ GET（下载），
/// 替代 webdav_client 库——该库在上传时用 Dio Stream 且未设置 content-type，
/// 会触发 Dio 的 `_MultiStream cannot be used to imply a default content-type` 报错。
///
/// 数据以 `.herobackup` 压缩包形式传输：打包时把图片作为真实文件收进 ZIP，
/// 从根本上解决「图片路径失效导致图片无法同步」的问题。
class SyncRepo {
  final LocalStorageRepo _localStorage;

  /// 云端数据快照的文件名（拼接在用户配置的目录路径下）。
  static const String remoteFileName = 'hero_data.${BackupPack.extension}';

  SyncRepo(this._localStorage);

  /// 拼接完整的远端文件路径：目录路径（如 /HeroAdventure）+ 文件名。
  static String _remoteFilePath(String dir) {
    var d = dir.trim();
    if (d.isEmpty) d = '/';
    if (!d.startsWith('/')) d = '/$d';
    if (!d.endsWith('/')) d = '$d/';
    return '$d$remoteFileName';
  }

  /// 组装完整的远端文件 URL（不含认证信息，认证通过 Header 传递）。
  static Uri _buildUri(String url, String dir) {
    var base = url.trim();
    if (!base.endsWith('/')) base = '$base/';
    // 去掉末尾多余的斜杠，避免 //。
    final filePath = _remoteFilePath(dir);
    final fullPath = '${base.replaceFirst(RegExp(r'/+$'), '')}$filePath';
    return Uri.parse(fullPath);
  }

  /// 生成请求头：二进制 content-type + HTTP Basic Auth。
  ///
  /// 认证信息用 Authorization 头（Base64 编码）传递，而非塞进 URL 的 userInfo，
  /// 避免账号/密码含特殊字符（@ : # % 中文等）时 Uri.parse 抛
  /// FormatException: Invalid character。
  Map<String, String> _headers(String username, String password) {
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
    };
    if (username.isNotEmpty) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $credentials';
    }
    return headers;
  }

  // 备份全量数据（含图片）到 WebDAV。
  // 上传后通过 PROPFIND 读取远端文件的修改时间（getlastmodified），
  // 作为数据版本判断依据（无需在 JSON 快照中写自定义字段）。
  Future<void> backupToWebDav({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final snapshot = await _localStorage.buildSnapshot();
    final bytes = await BackupPack.pack(snapshot);

    // 先确保远端目录存在（坚果云上传到不存在目录会报 409 AncestorsNotFound）。
    await _ensureRemoteDirectory(
      url: url,
      username: username,
      password: password,
      directory: directory,
    );

    final uri = _buildUri(url, directory);
    final resp = await http
        .put(uri, headers: _headers(username, password), body: bytes)
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('WebDAV 上传失败：HTTP ${resp.statusCode} ${resp.body}');
    }

    // 上传成功后，读取远端文件的修改时间戳，本机记录作为「最近同步版本」。
    final modified = await fetchRemoteModified(
      url: url,
      username: username,
      password: password,
      directory: directory,
    );
    if (modified != null) {
      await _localStorage.setLastSyncedUploadAt(modified);
    }
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

    // 恢复后记录远端文件修改时间戳，避免启动检查时重复提示。
    final modified = await fetchRemoteModified(
      url: url,
      username: username,
      password: password,
      directory: directory,
    );
    if (modified != null) {
      await _localStorage.setLastSyncedUploadAt(modified);
    }
  }

  /// 拉取云端快照（不写入本地），返回可交给 restoreSnapshot 的 JSON Map。
  Future<Map<String, dynamic>> fetchRemoteSnapshot({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final uri = _buildUri(url, directory);
    final resp = await http
        .get(uri, headers: _headers(username, password))
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('WebDAV 读取失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    // 云端存的是 .herobackup 压缩包，解包得到数据 + 还原图片。
    return BackupPack.unpack(resp.bodyBytes);
  }

  /// 读取云端文件的最后修改时间（WebDAV 的 getlastmodified 属性）。
  ///
  /// 通过 PROPFIND 请求获取，这是坚果云等 WebDAV 服务原生支持的版本依据，
  /// 返回 ISO 8601 时间字符串（如 '2026-03-02T10:00:00Z'）。
  /// 云端无此文件时返回 null。
  Future<String?> fetchRemoteModified({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final uri = _buildUri(url, directory);
    // PROPFIND 请求体：请求 getlastmodified 属性。
    const body = '''
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:getlastmodified/>
  </D:prop>
</D:propfind>''';

    final headers = _headers(username, password);
    headers['Depth'] = '0';
    headers['Content-Type'] = 'application/xml; charset=utf-8';

    // http 包没有 propfind 快捷方法，用 Request + send 发送任意 method。
    final request = http.Request('PROPFIND', uri);
    request.headers.addAll(headers);
    request.body = body;

    final client = http.Client();
    try {
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);

      // 404 表示远端文件不存在。
      if (resp.statusCode == 404) return null;
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('WebDAV 读取属性失败：HTTP ${resp.statusCode} ${resp.body}');
      }

      // 从返回的 XML 中提取 <getlastmodified> 的值。
      return _parseLastModified(resp.body);
    } finally {
      client.close();
    }
  }

  /// 从 PROPFIND 返回的 XML 中提取 getlastmodified 时间。
  static String? _parseLastModified(String xml) {
    final match = RegExp(
      r'<[^>]*getlastmodified[^>]*>([^<]+)<',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match == null) return null;
    return match.group(1)!.trim();
  }

  /// 确保远端目录存在（不存在则逐级创建）。
  ///
  /// 坚果云上传到不存在的目录会返回 409 AncestorsNotFound，
  /// 因此上传前需用 MKCOL 逐级创建目录。
  /// MKCOL 状态码约定：201=创建成功，405=已存在，409=父目录不存在。
  Future<void> _ensureRemoteDirectory({
    required String url,
    required String username,
    required String password,
    required String directory,
  }) async {
    final dir = _normalizeDirectory(directory);
    if (dir == '/' || dir.isEmpty) return; // 根目录无需创建

    final client = http.Client();
    try {
      // 逐级创建：/HeroAdventure 拆成 /Hero、/Hero/Adventure 等
      final segments = dir.split('/').where((s) => s.isNotEmpty).toList();

      var current = '';
      for (final seg in segments) {
        current = '$current/$seg';
        final ok = await _tryMkdir(client, url, current, username, password);
        if (!ok) {
          throw Exception('WebDAV 创建目录失败：$current');
        }
      }
    } finally {
      client.close();
    }
  }

  /// 创建单个目录；返回 true 表示成功或已存在。
  Future<bool> _tryMkdir(
    http.Client client,
    String url,
    String dirPath,
    String username,
    String password,
  ) async {
    var base = url.trim();
    if (!base.endsWith('/')) base = '$base/';
    final fullPath = '${base.replaceFirst(RegExp(r'/+$'), '')}$dirPath/';
    final uri = Uri.parse(fullPath);

    final request = http.Request('MKCOL', uri);
    request.headers.addAll(_headers(username, password));

    final streamed = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    final resp = await http.Response.fromStream(streamed);

    // 201=创建成功，405=目录已存在（视为成功）
    return resp.statusCode == 201 || resp.statusCode == 405;
  }

  /// 规范化目录路径：去掉首尾空格，补前导斜杠，去掉末尾斜杠。
  static String _normalizeDirectory(String dir) {
    var d = dir.trim();
    if (d.isEmpty) return '/';
    if (!d.startsWith('/')) d = '/$d';
    while (d.length > 1 && d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }
}
