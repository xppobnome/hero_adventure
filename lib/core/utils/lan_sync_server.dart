import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../data/repositories/local_storage_repo.dart';

/// 局域网面对面同步服务（换机助手式）。
///
/// 发送方：开启一个本地 HTTP 服务器，把全量快照（含图片 base64）挂载到一个
/// 带 token 的路径上；二维码只承载「http://发送方IP:端口/token」这一轻量握手信息。
/// 接收方：扫描二维码 → 解析 IP:端口 → HTTP GET 拉取快照 → restoreSnapshot。
///
/// 相比把整份数据塞进单个二维码，局域网传输不受二维码容量限制，图片也能完整同步。
class LanSyncServer {
  LanSyncServer._();

  /// 获取本机局域网 IPv4 地址（用于让另一台设备访问）。
  ///
  /// 返回 null 表示当前不在有效局域网（可能是蜂窝网络或未连 WiFi），
  /// 此时应提示用户连接同一 WiFi 或开启热点。
  static Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // 排除回环地址，取 192.168.* / 10.* / 172.16-31.* 等局域网段。
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              _isPrivate172(ip)) {
            return ip;
          }
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static bool _isPrivate172(String ip) {
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  /// 开启局域网同步服务器，返回 (局域网IP, 端口, token)。
  ///
  /// 服务器只接受一个「握手路径」请求，返回快照 JSON 后自动关闭。
  /// 使用随机 token 防止同一局域网内误连。
  static Future<LanServerInfo> start(LocalStorageRepo storage) async {
    final ip = await getLocalIp();
    if (ip == null) {
      throw Exception('未检测到局域网，请连接同一 WiFi 或开启热点');
    }

    // 一次性读取快照（含图片压缩），挂到内存中等待拉取。
    final snapshot = await storage.buildSnapshot();
    final body = utf8.encode(jsonEncode(snapshot));

    final token = _randomToken();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;

    // 后台监听，收到一次握手请求即返回数据并关闭。
    server.listen((request) async {
      try {
        if (request.uri.path == '/sync/$token') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'application',
            'json',
            charset: 'utf-8',
          );
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          request.response.add(body);
          await request.response.close();
          await server.close(force: true);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      } catch (_) {
        try {
          await request.response.close();
        } catch (_) {}
      }
    });

    return LanServerInfo(ip: ip, port: port, token: token, server: server);
  }

  /// 从发送方拉取快照并恢复到本地。
  static Future<void> fetchAndRestore(
    LocalStorageRepo storage,
    String ip,
    int port,
    String token,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/sync/$token'),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('拉取失败：HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final snapshot = jsonDecode(body) as Map<String, dynamic>;
      await storage.restoreSnapshot(snapshot);
    } finally {
      client.close();
    }
  }

  /// 生成握手 URL（写入二维码）。
  static String handshakeUrl(LanServerInfo info) =>
      'http://${info.ip}:${info.port}/sync/${info.token}';

  static String _randomToken() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

/// 局域网服务器信息。
class LanServerInfo {
  const LanServerInfo({
    required this.ip,
    required this.port,
    required this.token,
    required this.server,
  });

  final String ip;
  final int port;
  final String token;
  final HttpServer server;
}
