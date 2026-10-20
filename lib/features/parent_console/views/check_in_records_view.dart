import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';

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
        children: [
          // 儿童筛选
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SizedBox(
              height: 40.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
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
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];
                      return _RecordCard(
                        record: r,
                        childName: childNameById[r.childId] ?? '未知',
                        taskTitle: taskTitleById[r.taskId] ?? '未知任务',
                        avatarImage: children.firstWhere((c) => c.id == r.childId,
                                orElse: () => children.first).avatarImage,
                      );
                    },
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
        label: Text(label, style: TextStyle(fontSize: 13.sp)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: UltramanTheme.blue.withValues(alpha: 0.2),
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

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/打卡记录_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(sb.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到: ${file.path}')),
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
      child: ListTile(
        leading: ChildAvatar(avatarImage: avatarImage, name: childName, size: 44.w),
        title: Text(taskTitle, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$childName · ${record.date}\n+${record.rewardCoins}币 / +${record.rewardExp}EXP',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: color, size: 20.w),
            SizedBox(height: 4.h),
            Text(label, style: TextStyle(fontSize: 11.sp, color: color)),
          ],
        ),
      ),
    );
  }
}
