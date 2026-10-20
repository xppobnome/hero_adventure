import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../domain/providers/task_provider.dart';
import '../task_edit_view.dart';

class TaskManagementTab extends ConsumerWidget {
  const TaskManagementTab({super.key});

  void _confirmDeleteTask(BuildContext context, WidgetRef ref, String taskId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除任务', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text('确定要删除这个防卫任务吗？儿童将无法再看到该任务。', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(taskProvider.notifier).removeTask(taskId);
              Navigator.pop(ctx);
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // 继承父级底色
      body: tasks.isEmpty
          ? Center(child: Text('暂无防卫任务，请点击右下角添加', style: TextStyle(fontSize: 16.sp, color: Colors.grey)))
          : ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              title: Text(task.title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '周期: ${task.typeLabel} | 奖励: ${task.rewardExp} EXP / ${task.rewardCoins} 币',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600)
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue, size: 24.r),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TaskEditView(taskToEdit: task)),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 24.r),
                    onPressed: () => _confirmDeleteTask(context, ref, task.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A0E9), // 计时器蓝
        child: Icon(Icons.add, color: Colors.white, size: 28.r),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskEditView()),
          );
        },
      ),
    );
  }
}