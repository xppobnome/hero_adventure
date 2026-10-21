import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repositories/local_storage_repo.dart';
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
      messenger.showSnackBar(
        SnackBar(content: Text('检查更新失败：$error'), backgroundColor: Colors.red),
      );
      return;
    }
    if (info == null) {
      messenger.showSnackBar(const SnackBar(content: Text('当前已是最新版本 ✓')));
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
          constraints: BoxConstraints(maxWidth: 400.w, maxHeight: 420.h),
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
              _launchDownload(info.downloadUrl);
            },
            child: Text('立即更新', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchDownload(String url) async {
    await UrlOpener.open(url);
  }

  /// 根据指定更新源获取最新版本信息。
  static Future<UpdateInfo?> _fetchLatestBySource(LocalStorageRepo storage) async {
    final source = storage.getUpdateSource();
    switch (source) {
      case sourceGitee:
        return _fetchGiteeRelease();
      case sourceGithub:
      default:
        return _fetchGithubRelease();
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
