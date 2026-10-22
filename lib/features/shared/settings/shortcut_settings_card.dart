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

    // 注意：不要在这里用 isPinnedShortcutSupported 做前置拦截。部分 ROM 的
    // isRequestPinShortcutSupported 会误报 false，导致直接走权限引导而根本
    // 没调用 requestPinShortcut。直接调用原生 createPinnedShortcut。
    //
    // 关键：requestPinShortcut 在国产 ROM 上即使权限被拦截也可能返回 true
    // （API 层面「请求被接受」，但系统确认框被静默拦截不弹出），因此不能
    // 只靠返回值判断成败。这里改为调用后【始终弹出引导对话框】，让用户
    // 自行确认系统是否弹框、并提供「前往系统设置」入口。

    setState(() => _creating = true);
    bool ok = false;
    String? error;
    try {
      // 复用 AppDisplay 统一解析名字与图标，保证与启动图/关于页一致。
      final label = AppDisplay.resolveName(storage, child);
      final iconPath = AppDisplay.resolveIconPath(storage, child);

      ok = await NativeTools.createPinnedShortcut(
        id: 'child_${child.id}',
        label: label,
        iconPath: iconPath.isEmpty ? null : iconPath,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => _creating = false);
    }

    if (!mounted) return;

    // 无论结果如何，都弹引导对话框，提供清晰的下一步操作。
    _showShortcutGuide(success: error == null && ok);
  }

  /// 快捷方式创建结果引导对话框。
  ///
  /// 国内定制 ROM（小米/华为/OPPO/vivo 等）对桌面快捷方式做了额外权限拦截，
  /// 系统原生确认框经常弹不出来。无论 requestPinShortcut 返回什么，都弹此框，
  /// 让用户确认结果并引导到系统设置手动授权。
  void _showShortcutGuide({required bool success}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(success ? '请确认快捷方式' : '需要开启快捷方式权限'),
          ],
        ),
        content: Text(
          success
              ? '已向系统发起创建请求。\n\n'
                    '如果手机屏幕上已经弹出确认框，请点击「添加」完成创建。\n'
                    '如果【没有弹出任何确认框】，说明手机系统拦截了请求'
                    '（小米 / 华为 / OPPO / vivo 等常见），请前往系统设置开启'
                    '「桌面快捷方式」权限后再回来重新创建。'
              : '创建请求被手机系统拦截，无法自动添加。\n\n'
                    '请前往系统设置，在「应用权限 / 权限管理」中找到'
                    '「桌面快捷方式」，将其设为「允许」，然后再回来重新创建。',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await NativeTools.openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('前往系统设置'),
          ),
        ],
      ),
    );
  }
}
