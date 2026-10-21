import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:path_provider/path_provider.dart';

/// 备份压缩包格式（自定义扩展名 `.herobackup`，本质是 ZIP）。
///
/// 相比把图片 base64 内嵌进 JSON，这里把图片作为**真实文件**打包进压缩包，
/// 从根本上解决「图片路径失效导致图片无法同步」的问题：
/// - 打包时，把当前能读到的图片文件复制进 `images/` 目录，并在 `data.json`
///   里记录「原路径 → 包内文件名」映射；读不到的文件直接跳过，不阻断整体备份。
/// - 解包时，把 `images/` 里的文件还原到应用私有目录，并把 data.json 里
///   记录的图片路径字段改写为还原后的新路径。
///
/// 包内结构：
/// ```
/// data.json            // 家庭/任务/奖励/打卡/兑换 + images 映射（不含 base64）
/// images/<name>.jpg    // 图片文件（真实字节）
/// ```
class BackupPack {
  BackupPack._();

  /// 包内数据文件名。
  static const String dataFileName = 'data.json';

  /// 包内图片目录名。
  static const String imagesDirName = 'images';

  /// 备份文件扩展名。
  static const String extension = 'herobackup';

  // ===== 打包 =====

  /// 把全量数据 + 图片打包成内存字节（供 WebDAV / 本地文件 / 面对面传输直接使用）。
  static Future<Uint8List> pack(Map<String, dynamic> snapshot) async {
    // 1) 提取图片：优先从磁盘路径读真实文件；失败时回退用 base64 兜底。
    final images = <String, Uint8List>{}; // 包内文件名 -> 字节
    final pathMap = <String, String>{}; // 原路径 -> 包内文件名

    final imagePaths = _collectImagePaths(snapshot);
    final base64Images = _extractBase64Images(snapshot);

    var index = 0;
    for (final path in imagePaths.toSet()) {
      index++;
      final ext = _extOf(path);
      final nameInPack = 'img_$index$ext';

      final bytes = await _readImageBytes(path) ??
          (base64Images[path] != null
              ? _tryDecodeBase64(base64Images[path]!)
              : null);
      if (bytes != null) {
        images[nameInPack] = bytes;
        pathMap[path] = nameInPack;
      }
    }

    // 2) 生成 data.json：数据 + 图片映射（不含 base64，避免体积膨胀）。
    final data = Map<String, dynamic>.from(snapshot);
    data.remove('images'); // 移除 base64 图片，改用 images/ 目录
    data['imageMap'] = pathMap; // 原路径 -> 包内文件名
    data['format'] = 'herobackup';
    data['formatVersion'] = 1;
    final dataJson = utf8.encode(jsonEncode(data));

    // 3) 打包 ZIP。
    final archive = ar.Archive();
    archive.addFile(
      ar.ArchiveFile(dataFileName, dataJson.length, dataJson),
    );
    for (final entry in images.entries) {
      final bytes = entry.value;
      archive.addFile(
        ar.ArchiveFile('$imagesDirName/${entry.key}', bytes.length, bytes),
      );
    }

    final encoder = ar.ZipEncoder();
    return Uint8List.fromList(encoder.encode(archive)!);
  }

  // ===== 解包 =====

  /// 从 `.herobackup` 字节解包，返回可交给 LocalStorageRepo.restoreSnapshot
  /// 的 JSON Map（图片已还原到私有目录，图片路径字段已改写为新路径）。
  static Future<Map<String, dynamic>> unpack(Uint8List bytes) async {
    final decoder = ar.ZipDecoder();
    final archive = decoder.decodeBytes(bytes);

    // 1) 找 data.json 与 images/ 下的文件。
    String? dataJson;
    final images = <String, Uint8List>{}; // 包内文件名 -> 字节
    for (final file in archive.files) {
      if (file.isFile) {
        final name = file.name;
        final content = file.content; // Uint8List
        if (name == dataFileName) {
          dataJson = utf8.decode(content);
        } else if (name.startsWith('$imagesDirName/')) {
          images[name.substring('$imagesDirName/'.length)] = content;
        }
      }
    }

    if (dataJson == null) {
      throw Exception('备份文件损坏：缺少 data.json');
    }

    final data = jsonDecode(dataJson) as Map<String, dynamic>;

    // 2) 还原图片到私有目录，得到「包内文件名 -> 新路径」。
    final restoredPathByPackName = <String, String>{};
    for (final entry in images.entries) {
      final newPath = await _writeToPrivateDir(entry.value, entry.key);
      if (newPath != null) {
        restoredPathByPackName[entry.key] = newPath;
      }
    }

    // 3) 用 imageMap 重写数据里的图片路径字段（指向还原后的私有目录路径）。
    final imageMap = data['imageMap'];
    if (imageMap is Map && imageMap.isNotEmpty) {
      // imageMap: 原路径 -> 包内文件名
      final newPathByOriginal = <String, String>{};
      for (final e in imageMap.entries) {
        final packName = e.value as String;
        final newPath = restoredPathByPackName[packName];
        if (newPath != null) {
          newPathByOriginal[e.key as String] = newPath;
        }
      }
      _rewriteImagePaths(data, newPathByOriginal);
      // 图片已按文件还原，路径字段已改写；置空 images 字段，
      // 避免 restoreSnapshot 里的 _restoreImages 用 base64 二次还原。
      data['images'] = const <String, String>{};
    }

    return data;
  }

  // ===== 内部工具 =====

  /// 收集快照中所有图片路径。
  static List<String> _collectImagePaths(Map<String, dynamic> snapshot) {
    final paths = <String>[];
    final familyJson = snapshot['family'];
    if (familyJson is Map) {
      final children = familyJson['children'];
      if (children is List) {
        for (final c in children) {
          if (c is Map && c['avatarImage'] is String) {
            final p = c['avatarImage'] as String;
            if (p.isNotEmpty) paths.add(p);
          }
        }
      }
    }
    final checkIns = snapshot['checkIns'];
    if (checkIns is List) {
      for (final c in checkIns) {
        if (c is Map && c['proofImage'] is String) {
          final p = c['proofImage'] as String;
          if (p.isNotEmpty) paths.add(p);
        }
      }
    }
    return paths;
  }

  /// 提取快照中已有的 base64 图片（兜底来源）。
  static Map<String, String> _extractBase64Images(Map<String, dynamic> snapshot) {
    final result = <String, String>{};
    final images = snapshot['images'];
    if (images is Map) {
      for (final e in images.entries) {
        if (e.value is String && (e.value as String).isNotEmpty) {
          result[e.key as String] = e.value as String;
        }
      }
    }
    return result;
  }

  /// 读磁盘文件字节；不存在/失败返回 null。
  static Future<Uint8List?> _readImageBytes(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _tryDecodeBase64(String base64) {
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  /// 把字节写入应用私有目录，返回新路径；失败返回 null。
  static Future<String?> _writeToPrivateDir(Uint8List bytes, String name) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${dir.path}/backup_images');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      // 去掉包内可能带的风险字符，只用安全文件名。
      final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${imageDir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 根据「原路径 -> 新路径」重写 data 里 family/checkIns 的图片路径字段。
  static void _rewriteImagePaths(
    Map<String, dynamic> data,
    Map<String, String> newPathByOriginal,
  ) {
    final familyJson = data['family'];
    if (familyJson is Map && familyJson['children'] is List) {
      for (final c in (familyJson['children'] as List)) {
        if (c is Map && c['avatarImage'] is String) {
          final old = c['avatarImage'] as String;
          final newPath = newPathByOriginal[old];
          if (newPath != null) c['avatarImage'] = newPath;
        }
      }
    }
    final checkIns = data['checkIns'];
    if (checkIns is List) {
      for (final c in checkIns) {
        if (c is Map && c['proofImage'] is String) {
          final old = c['proofImage'] as String;
          final newPath = newPathByOriginal[old];
          if (newPath != null) c['proofImage'] = newPath;
        }
      }
    }
  }

  /// 推断扩展名。
  static String _extOf(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.jpeg')) return '.jpeg';
    return '.jpg';
  }
}
