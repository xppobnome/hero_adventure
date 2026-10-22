import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/ultraman_visuals.dart';
import '../../../../domain/providers/task_provider.dart';
import '../../../../domain/providers/theme_provider.dart';
import '../task_edit_view.dart';

/// 家长端：防卫任务管理。
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

  /// 周期类型对应的主题色（用于卡片左侧色条与标签）。
  Color _typeColor(String type) {
    switch (type) {
      case 'daily':
        return UltramanTheme.blue;
      case 'weekly':
        return UltramanTheme.gold;
      case 'once':
        return const Color(0xFFE6483D);
      case 'math':
        return const Color(0xFF7C4DFF);
      case 'checkin_week':
      case 'checkin_month':
        return const Color(0xFF26A69A);
      case 'custom_days':
      case 'custom_range':
        return const Color(0xFFEF6C00);
      default:
        return UltramanTheme.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // 继承父级底色
      body: tasks.isEmpty
          ? Center(child: Text('暂无防卫任务，请点击右下角添加', style: TextStyle(fontSize: 16.sp, color: Colors.grey)))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final accent = _typeColor(task.type);
                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14.r),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TaskEditView(taskToEdit: task)),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Row(
                            children: [
                              // 怪兽图标 + 类型色环
                              Container(
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: MonsterAvatar(iconName: task.iconName, size: 40),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (task.requirePhoto) ...[
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '需拍照',
                                              style: TextStyle(fontSize: 9.sp, color: Colors.orange, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            task.typeLabel,
                                            style: TextStyle(fontSize: 10.sp, color: accent, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Flexible(
                                          child: Text(
                                            '奖励 ${task.rewardExp} EXP / ${task.rewardCoins} 币',
                                            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // 删除按钮（整卡点击即可进入编辑）
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red, size: 22.r),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                onPressed: () => _confirmDeleteTask(context, ref, task.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
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
