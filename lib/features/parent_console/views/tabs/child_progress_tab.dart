import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/models/check_in_record.dart';
import '../../../../domain/check_in_logic.dart';
import '../../../../domain/providers/check_in_provider.dart';
import '../../../../domain/providers/family_provider.dart';
import '../../../../domain/providers/stats_provider.dart';
import '../../../../domain/providers/task_provider.dart';
import '../../../../domain/providers/theme_provider.dart';
import '../../../child_adventure/widgets/child_dashboard.dart';

/// 家长端：查看各儿童任务进度。
class ChildProgressTab extends ConsumerWidget {
  const ChildProgressTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProfileProvider);
    if (family == null || family.children.isEmpty) {
      return const Center(child: Text('暂无儿童档案', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: family.children.length,
      itemBuilder: (context, index) {
        final child = family.children[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${child.name} 的闯关进度',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                ChildDashboard(childId: child.id),
                SizedBox(height: 8.h),
                _buildProgressDetail(ref, child.id),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressDetail(WidgetRef ref, String childId) {
    final tasks = ref.watch(taskProvider);
    final records = ref.watch(childCheckInProvider(childId));
    final today = _today();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今日任务完成情况', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h),
        ...tasks.map((task) {
          final done = CheckInLogic.isCompleted(
            task: task, childId: childId, date: today, records: records,
          );
          final pending = CheckInLogic.isPending(
            task: task, childId: childId, date: today, records: records,
          );
          // 打卡一周任务额外显示累计进度
          final bool isCheckinWeek = task.type == 'checkin_week';
          final String weekProgress = isCheckinWeek
              ? CheckInLogic.checkinWeekProgress(task: task, childId: childId, records: records)
              : '';
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : pending
                          ? Icons.hourglass_top
                          : Icons.radio_button_unchecked,
                  color: done ? Colors.green : pending ? UltramanTheme.gold : Colors.grey,
                  size: 20.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: TextStyle(fontSize: 14.sp)),
                      Text(
                        isCheckinWeek
                            ? '周期: 打卡一周 · 进度 $weekProgress'
                            : '周期: ${task.cycleDescription}',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  done ? '已完成' : pending ? '待审核' : '未完成',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: done ? Colors.green : pending ? Colors.orange : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}
