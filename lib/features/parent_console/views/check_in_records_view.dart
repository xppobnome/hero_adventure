import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/native_tools.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../data/models/check_in_record.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 打卡记录查看与导出：家长可查看所有儿童的每一次打卡记录，并导出为 CSV。
class CheckInRecordsView extends ConsumerStatefulWidget {
  const CheckInRecordsView({super.key});

  @override
  ConsumerState<CheckInRecordsView> createState() => _CheckInRecordsViewState();
}

class _CheckInRecordsViewState extends ConsumerState<CheckInRecordsView> {
  String? _filterChildId; // null = 全部儿童
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    final allRecords = ref.watch(checkInProvider);
    final tasks = ref.watch(taskProvider);

    final children = family?.children ?? [];
    final records = _filterChildId == null
        ? allRecords
        : allRecords.where((r) => r.childId == _filterChildId).toList();

    // 按创建时间降序
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final taskTitleById = <String, String>{
      for (final t in tasks) t.id: t.title,
    };
    final childNameById = <String, String>{
      for (final c in children) c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('打卡记录', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: '导出记录',
            onPressed: _exporting
                ? null
                : () => _exportCsv(context, records, childNameById, taskTitleById),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 儿童筛选（白色背景占满整行宽度）
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('全部', _filterChildId == null, () {
                    setState(() => _filterChildId = null);
                  }),
                  for (final c in children)
                    _filterChip(c.name, _filterChildId == c.id, () {
                      setState(() => _filterChildId = c.id);
                    }),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: records.isEmpty
                ? Center(child: Text('暂无打卡记录', style: TextStyle(fontSize: 15.sp, color: Colors.grey)))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final r = records[index];
                          return _RecordCard(
                            record: r,
                            childName: childNameById[r.childId] ?? '未知',
                            taskTitle: taskTitleById[r.taskId] ?? '未知任务',
                            avatarImage: children.firstWhere(
                                    (c) => c.id == r.childId,
                                    orElse: () => children.first)
                                .avatarImage,
                          );
                        },
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 13.sp),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: UltramanTheme.blue.withValues(alpha: 0.2),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<CheckInRecord> records,
    Map<String, String> childNameById,
    Map<String, String> taskTitleById,
  ) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无记录可导出')));
      return;
    }
    setState(() => _exporting = true);
    try {
      final sb = StringBuffer();
      // BOM 让 Excel 正确识别 UTF-8
      sb.write('\uFEFF');
      sb.writeln('儿童姓名,任务,状态,日期,奖励币,奖励经验,打卡时间');
      for (final r in records) {
        final status = switch (r.status) {
          'completed' => '已完成',
          'pending' => '待审核',
          'rejected' => '已驳回',
          _ => r.status,
        };
        final time =
            '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')} '
            '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
        sb.writeln('${_csvEscape(childNameById[r.childId] ?? '未知')},'
            '${_csvEscape(taskTitleById[r.taskId] ?? '未知任务')},'
            '$status,'
            '${r.date},'
            '${r.rewardCoins},'
            '${r.rewardExp},'
            '$time');
      }

      // 生成 CSV 字节（含 BOM，让 Excel 正确识别 UTF-8）。
      final bytes = Uint8List.fromList(utf8.encode(sb.toString()));

      // 通过系统保存对话框导出到公共目录（默认可选下载目录），
      // 用户选择保存位置后，直接用系统应用选择器打开该文件。
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final fileName =
          '打卡记录_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.csv';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出打卡记录',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );

      if (path == null) {
        if (mounted) setState(() => _exporting = false);
        return; // 用户取消
      }

      // Android 的 saveFile 已通过 bytes 写入；非 Android 需自行写文件。
      if (!Platform.isAndroid) {
        await File(path).writeAsBytes(bytes);
      }

      if (!mounted) return;

      // 弹出系统「选择打开方式」，让用户直接打开刚导出的记录。
      final opened = await NativeTools.openFile(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(opened ? '已导出并打开：$path' : '已导出到：$path'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

class _RecordCard extends StatelessWidget {
  final CheckInRecord record;
  final String childName;
  final String taskTitle;
  final String avatarImage;

  const _RecordCard({
    required this.record,
    required this.childName,
    required this.taskTitle,
    required this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (record.status) {
      'completed' => (Colors.green, '已完成', Icons.check_circle),
      'pending' => (UltramanTheme.gold, '待审核', Icons.hourglass_top),
      'rejected' => (Colors.red, '已驳回', Icons.cancel),
      _ => (Colors.grey, record.status, Icons.info),
    };

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChildAvatar(avatarImage: avatarImage, name: childName, size: 44.w),
            SizedBox(width: 12.w),
            // 中间文字区：标题 + 副标题，用 Flexible 自适应避免溢出
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskTitle,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$childName · ${record.date}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '+${record.rewardCoins}币 / +${record.rewardExp}EXP',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            // 右侧状态图标 + 文字
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(icon, color: color, size: 20.w),
                SizedBox(height: 4.h),
                Text(label, style: TextStyle(fontSize: 11.sp, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
