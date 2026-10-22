import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/local_storage_repo.dart';
import 'native_tools.dart';
import 'url_opener.dart';

/// 应用更新检查服务。
///
/// 支持三种更新源（在家长设置「检查更新」里选择）：
/// - GitHub：仓库 Release（tag 形如 v1.1.0，描述填更新公告，附件传 APK）。
/// - Gitee：仓库「发行版 Release」，API 结构与 GitHub 一致，适合国内网络。
/// - 网盘：用户配置一个 JSON 公告直链（version/changelog/downloadUrl），
///   下载地址可指向任意网盘分享链接 / 直链。
///
/// 【使用前配置】：把 [githubRepo] / [giteeRepo] 改成实际仓库 owner/repo。
class UpdateService {
  UpdateService._();

  /// GitHub 仓库（owner/repo）。
  static const String githubRepo = 'xppobnome/hero_adventure';

  /// Gitee 仓库（owner/repo）。对应 https://gitee.com/xppobnome/hero_adventure
  static const String giteeRepo = 'xppobnome/hero_adventure';

  /// 两种更新源标识（GitHub / Gitee）。
  static const String sourceGithub = 'github';
  static const String sourceGitee = 'gitee';

  /// 网盘下载地址（蓝奏云，独立按钮，不做版本比较）。
  static const String netdiskUrl = 'https://xpp.lanzouc.com/b0lp4bef';

  /// 更新源显示名（供设置界面展示）。
  static const Map<String, String> sourceLabels = {
    sourceGithub: 'GitHub',
    sourceGitee: 'Gitee',
  };

  /// 检查远程最新版本信息。
  ///
  /// 返回 null 表示无更新（远程版本 <= 当前版本）。
  /// 抛异常表示网络/配置问题，由调用方决定如何提示。
  static Future<UpdateInfo?> checkForUpdate(LocalStorageRepo storage) async {
    final info = await _fetchLatestBySource(storage);
    if (info == null) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // 来自 pubspec.yaml 的 version

    if (_compareVersions(info.version, currentVersion) <= 0) {
      return null; // 已是最新
    }
    return info;
  }

  /// 启动时的自动检查入口：尊重「自动检查开关 / 忽略版本 / 永久忽略」设置，
  /// 有更新且未被忽略时弹出更新弹窗。
  static Future<void> checkOnStartup(
    BuildContext context,
    LocalStorageRepo storage,
  ) async {
    if (!storage.getUpdateAutoCheck()) return; // 用户关闭了自动检查
    if (storage.getUpdatePermanentIgnored()) return; // 永久忽略
    try {
      final info = await checkForUpdate(storage);
      if (info == null) return;
      if (info.version == storage.getUpdateIgnoredVersion())
        return; // 本版本已选「下个版本提醒我」
      if (!context.mounted) return;
      await showUpdateDialog(context, storage, info);
    } catch (_) {
      // 启动时静默失败，不打扰用户。
    }
  }

  /// 手动「检查更新」按钮入口：显示检查过程与结果反馈。
  static Future<void> checkManually(
    BuildContext context,
    LocalStorageRepo storage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    UpdateInfo? info;
    Object? error;
    try {
      info = await checkForUpdate(storage);
    } catch (e) {
      error = e;
    }
    // 关闭 loading 弹窗（它是当前唯一打开的 dialog）。
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;
    if (error != null) {
      // 连不上网 / 状态码非 200：提示检查异常，引导去网盘手动更新。
      messenger.showSnackBar(
        SnackBar(
          content: const Text('检查更新异常，可从网盘下载里更新'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: '去网盘',
            textColor: Colors.white,
            onPressed: () => openNetdisk(context),
          ),
        ),
      );
      return;
    }
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('当前版本已是最新版')),
      );
      return;
    }
    await showUpdateDialog(context, storage, info);
  }

  /// 「网盘下载」独立按钮：直接跳转浏览器打开蓝奏云下载页。
  static Future<void> openNetdisk(BuildContext context) async {
    await UrlOpener.open(netdiskUrl, context: context);
  }

  /// 更新弹窗：展示更新公告 + 三个按钮。
  static Future<void> showUpdateDialog(
    BuildContext context,
    LocalStorageRepo storage,
    UpdateInfo info,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.rocket_launch,
              color: const Color(0xFF00A0E9),
              size: 26.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '发现新版本 ${info.version}',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          // 固定逻辑像素约束弹窗尺寸，避免 screenutil 的 .w/.h 在平板竖屏/手机上
          // 缩放不一致导致弹窗「细长」。高度收紧（300），公告区内容多时滚动展示。
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '更新公告',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    info.changelog.isEmpty ? '暂无更新说明' : info.changelog,
                    style: TextStyle(fontSize: 13.sp, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // 永久忽略更新
          TextButton(
            onPressed: () {
              storage.setUpdatePermanentIgnored(true);
              // 同步关闭「自动检查更新」，但保留用户可再手动开启的能力。
              storage.setUpdateAutoCheck(false);
              Navigator.pop(ctx);
            },
            child: Text(
              '永久忽略',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey),
            ),
          ),
          // 下个版本提醒我
          TextButton(
            onPressed: () {
              storage.setUpdateIgnoredVersion(info.version);
              Navigator.pop(ctx);
            },
            child: Text('下个版本提醒我', style: TextStyle(fontSize: 13.sp)),
          ),
          // 确定更新
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A0E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              storage.setUpdateIgnoredVersion(''); // 主动更新时清除忽略标记
              Navigator.pop(ctx);
              _downloadAndInstall(context, info);
            },
            child: Text('立即更新', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  /// 自动下载 APK 到公共下载目录，下载完成后触发系统安装器。
  ///
  /// 下载过程弹一个带进度提示的对话框（不可关闭），完成后关闭并安装。
  static Future<void> _downloadAndInstall(
    BuildContext context,
    UpdateInfo info,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    // 用 ValueNotifier 驱动进度对话框刷新。
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>('正在连接...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('正在下载更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (_, p, __) => LinearProgressIndicator(value: p),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (_, s, __) => Text(s, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (_, p, __) => Text(
                '${(p * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    String? apkPath;
    Object? error;
    try {
      apkPath = await _downloadApk(
        info.downloadUrl,
        info.version,
        onProgress: (p, s) {
          progressNotifier.value = p;
          statusNotifier.value = s;
        },
      );
    } catch (e) {
      error = e;
    }

    // 关闭下载进度对话框。
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;

    if (error != null || apkPath == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('下载失败：$error，已为你打开浏览器下载页'),
          backgroundColor: Colors.red,
        ),
      );
      // 兜底：退回浏览器下载。
      await _launchDownload(info.downloadUrl);
      return;
    }

    // 触发系统安装器。
    final installed = await NativeTools.installApk(apkPath);
    if (!installed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('无法自动安装，请到系统设置为本应用开启「安装未知来源应用」权限后重试'),
          backgroundColor: Colors.orange,
        ),
      );
      // 引导用户去开启安装权限。
      await NativeTools.openAppSettings();
    }
  }

  /// 下载 APK 到公共下载目录，返回本地文件路径。
  static Future<String> _downloadApk(
    String url,
    String version, {
    required void Function(double progress, String status) onProgress,
  }) async {
    if (url.isEmpty) {
      throw Exception('该版本未提供 APK 下载地址');
    }

    // 优先下载到公共下载目录（Android 的 Download/），失败则回退应用文档目录。
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();
    if (dir == null) {
      throw Exception('无法获取下载目录');
    }

    final file = File('${dir.path}/hero_adventure_v$version.apk');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('下载失败 HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(
            received / total,
            '正在下载 ${(received / 1024 / 1024).toStringAsFixed(1)} MB'
                ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB',
          );
        } else {
          onProgress(0, '正在下载 ${(received / 1024 / 1024).toStringAsFixed(1)} MB');
        }
      }
      await sink.close();

      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('下载文件为空');
      }
      return file.path;
    } finally {
      client.close();
    }
  }

  static Future<void> _launchDownload(String url) async {
    await UrlOpener.open(url);
  }

  /// 根据指定更新源获取最新版本信息。
  static Future<UpdateInfo?> _fetchLatestBySource(LocalStorageRepo storage) async {
    final source = storage.getUpdateSource();
    switch (source) {
      case sourceGithub:
        return _fetchGithubRelease();
      case sourceGitee:
      default:
        return _fetchGiteeRelease();
    }
  }

  /// GitHub Releases 最新版本。
  static Future<UpdateInfo?> _fetchGithubRelease() async {
    final apiUrl =
        'https://api.github.com/repos/$githubRepo/releases/latest';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(apiUrl));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'hero_adventure');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('GitHub API 返回 ${response.statusCode}');
      }
      final body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      return _parseRelease(body, fallbackHtmlUrl: body['html_url'] as String?);
    } finally {
      client.close();
    }
  }

  /// Gitee Releases 最新版本（API 结构与 GitHub 一致）。
  static Future<UpdateInfo?> _fetchGiteeRelease() async {
    final apiUrl =
        'https://gitee.com/api/v5/repos/$giteeRepo/releases/latest';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(apiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'hero_adventure');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Gitee API 返回 ${response.statusCode}');
      }
      final body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      return _parseRelease(body, fallbackHtmlUrl: body['html_url'] as String?);
    } finally {
      client.close();
    }
  }

  /// 解析 GitHub / Gitee 共用的 Release JSON 结构。
  static UpdateInfo? _parseRelease(
    Map<String, dynamic> body, {
    String? fallbackHtmlUrl,
  }) {
    final tagName = (body['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tagName.isEmpty) return null;

    // 优先取 APK 附件下载地址；无附件时退回 Release 页面。
    String downloadUrl = fallbackHtmlUrl ?? '';
    final assets = body['assets'] as List? ?? [];
    for (final asset in assets) {
      final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        downloadUrl = asset['browser_download_url'] as String;
        break;
      }
    }

    return UpdateInfo(
      version: tagName,
      changelog: (body['body'] as String? ?? body['name'] as String? ?? '')
          .trim(),
      downloadUrl: downloadUrl,
    );
  }

  /// 简单语义化版本比较：返回 >0 表示 [a] 更新，<0 表示 [b] 更新，0 相同。
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}

/// 远程最新版本信息。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
  });

  final String version;
  final String changelog;
  final String downloadUrl;
}
