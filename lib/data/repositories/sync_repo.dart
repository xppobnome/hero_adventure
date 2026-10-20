import 'dart:convert';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'local_storage_repo.dart';

class SyncRepo {
  final LocalStorageRepo _localStorage;

  SyncRepo(this._localStorage);

  webdav.Client _getWebDavClient(String url, String username, String password) {
    return webdav.newClient(
      url,
      user: username,
      password: password,
    );
  }

  // 备份全量数据到 WebDAV
  Future<void> backupToWebDav({
    required String url,
    required String username,
    required String password,
  }) async {
    final client = _getWebDavClient(url, username, password);

    final snapshot = _localStorage.buildSnapshot();
    final jsonString = jsonEncode(snapshot);
    final bytesData = utf8.encode(jsonString);

    await client.write('/hero_data.json', bytesData);
  }

  // 从 WebDAV 恢复全量数据
  Future<void> restoreFromWebDav({
    required String url,
    required String username,
    required String password,
  }) async {
    final client = _getWebDavClient(url, username, password);

    final responseBytes = await client.read('/hero_data.json');
    final jsonString = utf8.decode(responseBytes);
    final snapshot = jsonDecode(jsonString) as Map<String, dynamic>;

    await _localStorage.restoreSnapshot(snapshot);
  }
}
