import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 图片压缩与编码工具。
///
/// 备份同步时，把本地图片（头像、打卡凭证）压缩后转为 base64 字符串嵌入快照；
/// 恢复时再把 base64 解码写回本地文件。这样图片内容能随快照一起
/// 通过 WebDAV / 二维码 / 本地文件三个通道同步，而非只同步一个失效的路径。
class ImageCompressor {
  ImageCompressor._();

  /// 压缩目标：最长边像素（超过则等比缩小）。
  static const int _maxDimension = 1024;

  /// JPEG 压缩质量（0-100）。
  static const int _jpegQuality = 70;

  /// 读取本地图片文件，压缩后返回 base64 字符串。
  ///
  /// [path] 不存在或不是有效图片时返回 null。
  static Future<String?> compressToBase64(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // 等比缩放，限制最长边，减小体积。
      img.Image resized = decoded;
      final longest = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      if (longest > _maxDimension) {
        resized = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? _maxDimension : null,
          height: decoded.height > decoded.width ? _maxDimension : null,
        );
      }

      // 统一重编码为 JPEG（透明 PNG 会先铺白底）。
      final encoded = img.encodeJpg(resized, quality: _jpegQuality);
      if (encoded == null) return null;
      return base64Encode(encoded);
    } catch (_) {
      return null; // 单张图片失败不阻断整体备份
    }
  }

  /// 把 base64 图片解码写回本地文件，返回文件路径。
  ///
  /// 文件名用 [fileName]（建议含唯一标识），统一存到应用文档目录的
  /// backup_images 子目录。失败返回 null。
  static Future<String?> saveBase64ToFile(
    String base64, {
    required String fileName,
  }) async {
    try {
      final bytes = base64Decode(base64);
      final dir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${dir.path}/backup_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final file = File('${imageDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 快速判断字符串是否像 base64（用于区分「本地路径」与「内嵌图片数据」）。
  static bool looksLikeBase64(String s) {
    if (s.length < 20) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(s);
  }

  /// 从 base64 解码出字节（供测试或特殊场景使用）。
  static Uint8List decode(String base64) => base64Decode(base64);

  /// 把 image_picker 返回的临时/cache 文件复制到应用文档目录的持久路径。
  ///
  /// image_picker 返回的路径通常位于系统 cache 目录，重启或系统清理后会失效，
  /// 导致后续 buildSnapshot 读不到文件、图片无法随快照同步。因此在选中图片时
  /// 就复制一份到文档目录，返回持久化后的绝对路径。
  ///
  /// 返回新路径；失败时回退返回原路径（不阻断选图流程）。
  static Future<String> persistPickedImage(String sourcePath) async {
    if (sourcePath.isEmpty) return sourcePath;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return sourcePath;

      final dir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${dir.path}/backup_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final ext = _extOf(sourcePath);
      final name =
          'pick_${DateTime.now().millisecondsSinceEpoch}$ext';
      final dest = File('${imageDir.path}/$name');
      await src.copy(dest.path);
      return dest.path;
    } catch (_) {
      return sourcePath; // 复制失败则退回原路径，不影响主流程
    }
  }

  /// 推断文件扩展名（默认 .jpg）。
  static String _extOf(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    return '.jpg';
  }
}
