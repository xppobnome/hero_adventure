import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 弹出头像选择来源 (拍照 / 相册)，返回选中的本地文件路径，取消返回 null。
Future<String?> pickAvatarImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 80,
    maxWidth: 800,
    maxHeight: 800,
  );
  return picked?.path;
}
