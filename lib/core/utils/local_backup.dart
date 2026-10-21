import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../data/repositories/local_storage_repo.dart';
import 'backup_pack.dart';

/// 本地文件备份工具。
///
/// 把全量数据 + 图片打包为 `.herobackup` 压缩文件导出，或从该文件导入恢复。
/// 「数据时空穿梭机」与「二维码同步」两个界面共用此实现，避免重复逻辑。
class LocalBackup {
  const LocalBackup._();

  /// 生成带时间戳的备份文件名。
  static String _backupFileName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'hero_backup_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '.${BackupPack.extension}';
  }

  /// 导出全量数据 + 图片到本地 `.herobackup` 压缩文件。
  ///
  /// 返回保存路径；用户取消时返回 null。
  static Future<String?> exportToFile(LocalStorageRepo storage) async {
    final snapshot = await storage.buildSnapshot();
    final bytes = await BackupPack.pack(snapshot);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出数据备份',
      fileName: _backupFileName(),
      type: FileType.custom,
      allowedExtensions: const [BackupPack.extension],
      bytes: bytes,
    );

    if (path == null) return null;

    // Android 的 saveFile 已通过 bytes 参数写入；iOS / 桌面仅返回路径，
    // 需要自行把字节写入返回的文件路径。
    if (!Platform.isAndroid) {
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
    }

    return path;
  }

  /// 从本地 `.herobackup` 压缩文件导入并恢复全量数据。
  ///
  /// 返回 true 表示导入成功；用户取消时返回 false。
  static Future<bool> importFromFile(LocalStorageRepo storage) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: const [BackupPack.extension],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return false;

    final picked = result.files.single;
    final Uint8List bytes;
    if (picked.bytes != null) {
      bytes = picked.bytes!;
    } else if (picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    } else {
      throw Exception('无法读取所选文件内容');
    }

    final snapshot = await BackupPack.unpack(bytes);
    await storage.restoreSnapshot(snapshot);
    return true;
  }
}
