import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/app_display.dart';
import '../../../core/utils/avatar_picker.dart';
import '../../../core/utils/native_tools.dart';
import '../../../data/models/child_profile.dart';
import '../../../domain/providers/family_provider.dart';

/// 「桌面快捷方式」设置卡片。
///
/// 允许家长设置是否用儿童头像 / 自选图片作为桌面快捷方式图标、
/// 用英雄昵称 / 自定义名字作为名字，并可立即创建/更新桌面快捷方式，
/// 以及隐藏原应用图标（仅保留快捷方式入口）。
class ShortcutSettingsCard extends ConsumerStatefulWidget {
  const ShortcutSettingsCard({super.key});

  @override
  ConsumerState<ShortcutSettingsCard> createState() =>
      _ShortcutSettingsCardState();
}

class _ShortcutSettingsCardState extends ConsumerState<ShortcutSettingsCard> {
  bool _creating = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(storageProvider).getShortcutCustomName(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    final storage = ref.watch(storageProvider);

    final children = family?.children ?? const [];
    final firstChild = children.isNotEmpty ? children.first : null;

    final useAvatar = storage.getShortcutUseAvatar();
    final useName = storage.getShortcutUseName();
    final customIconPath = storage.getShortcutIconPath();
    final useCustomDisplay = storage.getUseCustomAppDisplay();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_to_home_screen, color: Colors.indigo, size: 24.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '桌面快捷方式',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '把儿童专属入口放到桌面，可自定义图标与名字',
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            title: Text('使用儿童头像作为图标', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              firstChild == null || firstChild.avatarImage.isEmpty
                  ? '尚未设置儿童头像，将使用默认图标'
                  : '已选择头像',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            value: useAvatar,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setShortcutUseAvatar(v);
              // 与「自定义图标图片」互斥：开启儿童头像时清空自定义图标。
              if (v) {
                await storage.setShortcutIconPath('');
              }
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          // 自选图片作图标（与「使用儿童头像」互斥）
          ListTile(
            dense: true,
            title: Text('自定义图标图片', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              customIconPath.isEmpty ? '从相册选择一张图片作为图标（可选）' : '已选择自定义图标',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customIconPath.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () async {
                      await storage.setShortcutIconPath('');
                      if (mounted) setState(() {});
                    },
                  ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _pickCustomIcon(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            title: Text('使用英雄昵称作为名字', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              firstChild != null && firstChild.name.isNotEmpty
                  ? '如「${firstChild.name}」→「${firstChild.name}英雄闯关冒险」'
                  : '如「小明」→「小明英雄闯关冒险」',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            value: useName,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setShortcutUseName(v);
              if (mounted) setState(() {});
            },
          ),
          if (!useName) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: TextField(
                controller: _nameController,
                onChanged: (v) async {
                  await storage.setShortcutCustomName(v);
                },
                decoration: InputDecoration(
                  labelText: '自定义名字（默认：小朋友冒险计划）',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
            ),
          ],
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            title: Text('启动图与关于页显示自定义内容', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              '开启后，开屏启动页与「关于」页面将显示自定义头像与名字',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            value: useCustomDisplay,
            activeColor: const Color(0xFF00A0E9),
            onChanged: (v) async {
              await storage.setUseCustomAppDisplay(v);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_to_home_screen, size: 20),
                label: Text(_creating ? '正在创建…' : '创建/更新桌面快捷方式'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A0E9),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                onPressed: _creating ? null : () => _createShortcut(firstChild),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            child: Text(
              '说明：桌面快捷方式是独立入口，不会替换应用本身的图标与名字。'
              'Android 8.0 及以上会弹出系统确认框，确认后添加到桌面。',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  /// 从相册选择一张图片作为自定义图标。
  Future<void> _pickCustomIcon() async {
    final path = await pickAvatarImage(context);
    if (path == null) return;
    final storage = ref.read(storageProvider);
    await storage.setShortcutIconPath(path);
    // 与「使用儿童头像」互斥：选择自定义图标时关闭儿童头像。
    await storage.setShortcutUseAvatar(false);
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已选择自定义图标'), backgroundColor: Colors.green),
      );
    }
  }

  /// 切换「隐藏原图标」开关（已移除：隐藏后快捷方式也会失效）。

  Future<void> _createShortcut(ChildProfile? firstChild) async {
    final storage = ref.read(storageProvider);
    final family = ref.read(familyProfileProvider);
    final child = firstChild ??
        (family?.children.isNotEmpty == true ? family!.children.first : null);

    if (child == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无儿童档案，无法创建快捷方式')),
      );
      return;
    }

    // 先检查设备是否支持桌面快捷方式（Android 8.0+ 且系统支持）。
    final supported = await NativeTools.isPinnedShortcutSupported();
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前设备不支持创建桌面快捷方式'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      // 复用 AppDisplay 统一解析名字与图标，保证与启动图/关于页一致。
      final label = AppDisplay.resolveName(storage, child);
      final iconPath = AppDisplay.resolveIconPath(storage, child);

      final ok = await NativeTools.createPinnedShortcut(
        id: 'child_${child.id}',
        label: label,
        iconPath: iconPath.isEmpty ? null : iconPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '已请求创建桌面快捷方式' : '创建快捷方式失败，请重试'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建快捷方式失败：$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
