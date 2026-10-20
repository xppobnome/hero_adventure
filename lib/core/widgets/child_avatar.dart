import 'dart:io';

import 'package:flutter/material.dart';

/// 儿童头像组件。
///
/// [avatarImage] 为本地文件路径时显示真实头像，否则显示默认占位头像
/// （用姓名首字 + 主题色圆形背景）。尺寸由 [size] 控制。
class ChildAvatar extends StatelessWidget {
  final String avatarImage;
  final String name;
  final double size;
  final Color color;

  const ChildAvatar({
    super.key,
    required this.avatarImage,
    required this.name,
    this.size = 48,
    this.color = const Color(0xFF00A0E9),
  });

  @override
  Widget build(BuildContext context) {
    final clip = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatarImage.isNotEmpty && File(avatarImage).existsSync()
            ? Image.file(
                File(avatarImage),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
    return clip;
  }

  Widget _placeholder() {
    return Container(
      color: color.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
