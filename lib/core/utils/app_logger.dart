import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全局日志工具：统一控制详细日志的输出。
///
/// 用法：
/// ```dart
/// AppLogger.d('SherpaTts', '模型下载完成 $bytes bytes');
/// ```
///
/// 说明：
/// - 开启日志（家长控制台 → 设置 → 开启日志）后，[d] / [w] / [e] 输出到
///   debugPrint + logcat，并**同时写入本地日志文件**（保存到手机公共
///   「下载 / Download」目录，方便用户直接找到后发给开发者排查问题）；
/// - 关闭时仅 [e]（错误）仍然输出，避免干扰正常使用。
///
/// 开启状态由 [AppLogger.enabled] 静态字段控制，应用启动时从存储读取，
/// 设置页切换时写入。
class AppLogger {
  AppLogger._();

  /// 是否开启详细日志。由 main / 设置页在启动时与切换时更新。
  static bool enabled = false;

  /// 是否已初始化文件写入（懒初始化，首次写日志时创建）。
  static bool _fileReady = false;

  /// 日志文件目录（公共 Download 目录）。
  static String? _logDir;

  /// 日志文件路径。
  static String? logFilePath;

  /// 初始化日志文件写入（懒调用，开启日志后首次写日志时触发）。
  ///
  /// 日志优先保存到手机公共「下载 / Download」目录（用户在文件管理器
  /// 即可直接找到，无需 adb、无权限问题）；公共目录获取失败时回退到
  /// 应用外部存储目录，保证日志一定能写入。
  /// 文件名形如 `hero_adventure_log_20261101_2030.txt`。
  static Future<void> _ensureFile() async {
    if (_fileReady) return;
    try {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = null;
      }
      if (dir == null) {
        try {
          dir = await getExternalStorageDirectory();
        } catch (_) {
          dir = null;
        }
      }
      if (dir == null) return;
      final now = DateTime.now();
      final stamp =
          '${now.year}${_2(now.month)}${_2(now.day)}_${_2(now.hour)}${_2(now.minute)}';
      final file = File('${dir.path}/hero_adventure_log_$stamp.txt');
      _logDir = dir.path;
      logFilePath = file.path;
      // 写文件头，标记本次日志会话开始。
      await file.writeAsString(
        '===== 英雄闯关计划 运行日志 =====\n'
        '开始时间: ${now.toString()}\n'
        '----------------------------------------\n',
        flush: true,
      );
      _fileReady = true;
    } catch (_) {
      // 获取目录失败时静默降级（仅控制台输出，不写文件）。
    }
  }

  /// 显式初始化日志文件（供设置页开启日志时调用，以便立即拿到文件路径提示用户）。
  static Future<void> ensureLogFile() => _ensureFile();

  static String _2(int n) => n.toString().padLeft(2, '0');

  /// 调试日志（仅开启时输出）。
  static void d(String tag, String message) {
    if (!enabled) return;
    _emit('D', tag, message);
  }

  /// 警告日志（仅开启时输出）。
  static void w(String tag, String message) {
    if (!enabled) return;
    _emit('W', tag, message);
  }

  /// 错误日志（始终输出，排查崩溃关键）。
  static void e(String tag, String message) {
    _emit('E', tag, message);
  }

  static void _emit(String level, String tag, String message) {
    final time = DateTime.now();
    final ts =
        '${_2(time.hour)}:${_2(time.minute)}:${_2(time.second)}.${time.millisecond.toString().padLeft(3, '0')}';
    final line = '[$ts][$level][$tag] $message';

    debugPrint(line);

    // 输出到系统日志（Android logcat / iOS os_log），便于真机抓取。
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        stdout.writeln(line);
      }
    } catch (_) {
      // 忽略系统日志写入失败。
    }

    // 写入本地日志文件（懒初始化）。
    _appendToFile(line);
  }

  static void _appendToFile(String line) {
    try {
      if (kIsWeb) return;
      // 异步初始化 + 追加；失败静默忽略，不影响主流程。
      _ensureFile().then((_) {
        final path = logFilePath;
        if (path == null) return;
        File(path).writeAsString('$line\n', mode: FileMode.append, flush: true);
      });
    } catch (_) {
      // 忽略文件写入失败。
    }
  }
}
