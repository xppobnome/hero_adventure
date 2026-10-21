import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 统一的「打开外部链接」工具。
///
/// 封装 url_launcher 的跳转逻辑，做多级降级以规避部分机型 / 热重载下
/// pigeon 通道未建立导致的 `Unable to establish connection on channel` 报错：
/// 1. 优先 `launchUrl(..., externalApplication)` 在外部浏览器打开；
/// 2. 失败则尝试 `launchUrl(..., platformDefault)`；
/// 3. 仍失败则提示用户手动复制链接。
class UrlOpener {
  UrlOpener._();

  /// 打开链接，失败时给出 SnackBar 提示（若提供了 [context]）。
  static Future<bool> open(String url, {BuildContext? context}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast(context, '链接格式不正确');
      return false;
    }

    // 方式 1：外部浏览器（最常用，能处理 http/https/网盘等）。
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // 通道异常，继续尝试下一种方式。
    }

    // 方式 2：平台默认方式。
    try {
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return true;
      }
    } catch (_) {
      // 忽略，走兜底提示。
    }

    _toast(context, '无法打开链接，请手动复制地址访问：$url');
    return false;
  }

  static void _toast(BuildContext? context, String msg) {
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
