import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/avatar_picker.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../data/models/child_profile.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../../../domain/hero_system.dart';

/// 儿童档案管理：家长端查看 / 新增 / 修改儿童档案 (姓名 / 头像 / 年龄)。
class ChildProfileManagementView extends ConsumerWidget {
  const ChildProfileManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProfileProvider);
    final children = family?.children ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('儿童档案管理', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SafeArea(
        top: false,
        child: children.isEmpty
            ? Center(child: Text('暂无小英雄档案', style: TextStyle(fontSize: 16.sp)))
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return _ChildProfileCard(child: child);
              },
            ),
        ),
      floatingActionButton: SafeArea(
        top: false,
        child: FloatingActionButton.extended(
          onPressed: () => showChildEditDialog(context, ref, null),
          backgroundColor: UltramanTheme.blue,
          icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
          label: Text('新增儿童', style: TextStyle(color: Colors.white, fontSize: 15.sp)),
        ),
      ),
    );
  }
}

/// 弹出儿童档案编辑 / 新增对话框。
/// [child] 为 null 表示新增，否则为修改。
Future<void> showChildEditDialog(
  BuildContext context,
  WidgetRef ref,
  ChildProfile? child,
) {
  return showDialog(
    context: context,
    builder: (ctx) => _ChildEditDialog(
      child: child,
      onSave: (name, avatar, age) {
        final notifier = ref.read(familyProfileProvider.notifier);
        if (child == null) {
          notifier.addChild(ChildProfile(
            id: const Uuid().v4(),
            name: name,
            avatarImage: avatar,
            age: age,
          ));
        } else {
          notifier.updateChildProfile(
            child.id,
            name: name,
            avatarImage: avatar,
            age: age,
          );
        }
      },
    ),
  );
}

class _ChildProfileCard extends ConsumerWidget {
  final ChildProfile child;
  const _ChildProfileCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = levelFromExp(child.exp);
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: ChildAvatar(
          avatarImage: child.avatarImage,
          name: child.name,
          size: 52.w,
        ),
        title: Text(child.name, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
        subtitle: Text(
          'LV.$level · ${child.age} 岁',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: UltramanTheme.blue, size: 22.w),
          onPressed: () => showChildEditDialog(context, ref, child),
        ),
      ),
    );
  }
}

/// 编辑 / 新增儿童档案弹窗。
class _ChildEditDialog extends StatefulWidget {
  final ChildProfile? child;
  final void Function(String name, String avatar, int age) onSave;
  const _ChildEditDialog({required this.child, required this.onSave});

  @override
  State<_ChildEditDialog> createState() => _ChildEditDialogState();
}

class _ChildEditDialogState extends State<_ChildEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late String _avatarImage;

  bool get _isEdit => widget.child != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.name ?? '');
    _ageController = TextEditingController(text: '${widget.child?.age ?? 6}');
    _avatarImage = widget.child?.avatarImage ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入儿童昵称')));
      return;
    }
    final age = int.tryParse(_ageController.text.trim()) ?? 6;
    widget.onSave(name, _avatarImage, age);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '修改儿童档案' : '新增儿童档案', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头像
            InkWell(
              onTap: () async {
                final path = await pickAvatarImage(context);
                if (path != null && mounted) {
                  setState(() => _avatarImage = path);
                }
              },
              borderRadius: BorderRadius.circular(50.r),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ChildAvatar(
                    avatarImage: _avatarImage,
                    name: _nameController.text,
                    size: 88.w,
                  ),
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A0E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 14.w, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: '年龄 (岁)',
                helperText: '用于匹配适龄的学习题目难度',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A0E9)),
          child: const Text('保存', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
