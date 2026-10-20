import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/reward_item.dart';
import '../../../../domain/providers/reward_provider.dart';

class RewardManagementTab extends ConsumerWidget {
  const RewardManagementTab({super.key});

  void _confirmDeleteReward(BuildContext context, WidgetRef ref, String rewardId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('下架奖励', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text('确定要从商城中移除这个奖励吗？', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(rewardProvider.notifier).removeReward(rewardId);
              Navigator.pop(ctx);
            },
            child: const Text('确认下架', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddRewardDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('新增商城奖励', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '奖励名称 (例：看动画片 30分钟)'),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '消耗能量币数量'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final cost = int.tryParse(costController.text.trim()) ?? 0;

              if (title.isNotEmpty && cost > 0) {
                final newReward = RewardItem(
                  id: const Uuid().v4(),
                  title: title,
                  costCoins: cost,
                  iconName: 'default_gift',
                );
                ref.read(rewardProvider.notifier).addReward(newReward);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A0E9)),
            child: const Text('上架奖励', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: rewards.isEmpty
          ? Center(child: Text('商城空空如也，请点击右下角上架奖励', style: TextStyle(fontSize: 16.sp, color: Colors.grey)))
          : ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: rewards.length,
        itemBuilder: (context, index) {
          final reward = rewards[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.card_giftcard, color: Colors.amber.shade700, size: 24.r),
              ),
              title: Text(reward.title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              subtitle: Text('消耗: ${reward.costCoins} 能量币', style: TextStyle(fontSize: 14.sp)),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 24.r),
                onPressed: () => _confirmDeleteReward(context, ref, reward.id),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A0E9), // 计时器蓝
        child: Icon(Icons.add, color: Colors.white, size: 28.r),
        onPressed: () => _showAddRewardDialog(context, ref),
      ),
    );
  }
}