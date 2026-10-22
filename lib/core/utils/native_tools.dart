import 'package:flutter/services.dart';

/// Android 原生工具桥接。
///
/// 通过 MethodChannel 调用 MainActivity.kt 中实现的原生能力：
/// - [openFile]：用系统应用打开本地文件（弹出「选择打开方式」）。
/// - [createPinnedShortcut]：创建桌面快捷方式，支持任意图标与名字。
class NativeTools {
  NativeTools._();

  static const MethodChannel _channel = MethodChannel(
    'com.xppobnome.hero_adventure/native_tools',
  );

  /// 用系统默认/用户选择的应用打开本地文件。
  ///
  /// 返回 true 表示已发起打开；false 或抛异常表示失败。
  static Future<bool> openFile(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFile', {'path': path});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 创建桌面快捷方式（Pinned Shortcut）。
  ///
  /// [label] 快捷方式显示的名字；[iconPath] 图标图片文件路径（可空，
  /// 为空时使用应用默认图标）。
  static Future<bool> createPinnedShortcut({
    required String id,
    required String label,
    String? iconPath,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('createPinnedShortcut', {
        'id': id,
        'label': label,
        'iconPath': iconPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 检查当前设备是否支持请求桌面快捷方式（Android 8.0+ 且系统支持）。
  static Future<bool> isPinnedShortcutSupported() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isPinnedShortcutSupported');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打开本应用的系统设置详情页（用于手动开启「创建桌面快捷方式」权限）。
  static Future<bool> openAppSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openAppSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 安装本地 APK（自动更新用）。
  ///
  /// [path] APK 文件绝对路径。返回 true 表示已触发系统安装器；
  /// false 或抛异常表示失败（可能是权限未开启或文件不存在）。
  static Future<bool> installApk(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>('installApk', {'path': path});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
