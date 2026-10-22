import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/reward_item.dart';
import '../../../../domain/providers/reward_provider.dart';
import '../../../../domain/providers/theme_provider.dart';

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

  /// 新增 / 编辑奖励弹窗（美化版）。
  /// [reward] 不为空时为「编辑」，否则为「新增」。
  void _showRewardDialog(BuildContext context, WidgetRef ref, {RewardItem? reward}) {
    final titleController = TextEditingController(text: reward?.title ?? '');
    final costController =
        TextEditingController(text: reward?.costCoins.toString() ?? '');
    bool requireApproval = reward?.requireApproval ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: UltramanTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 22.r),
              ),
              SizedBox(width: 10.w),
              Text(
                reward == null ? '新增商城奖励' : '编辑商城奖励',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 奖励名称
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: '奖励名称 (例：看动画片 30分钟)',
                    prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF5F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                // 能量币数量
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '消耗能量币数量',
                    prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF5F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                // 审核开关
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: SwitchListTile(
                    title: Text('无需审核', style: TextStyle(fontSize: 14.sp)),
                    subtitle: Text(
                      '开启后儿童兑换即发放，无需家长审核',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    ),
                    value: !requireApproval,
                    activeColor: UltramanTheme.blue,
                    onChanged: (v) => setState(() => requireApproval = !v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final cost = int.tryParse(costController.text.trim()) ?? 0;

                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入奖励名称'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (cost <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效的能量币数量'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (reward == null) {
                  // 新增
                  ref.read(rewardProvider.notifier).addReward(
                        RewardItem(
                          id: const Uuid().v4(),
                          title: title,
                          costCoins: cost,
                          iconName: 'default_gift',
                          requireApproval: requireApproval,
                        ),
                      );
                } else {
                  // 编辑
                  ref.read(rewardProvider.notifier).updateReward(
                        RewardItem(
                          id: reward.id,
                          title: title,
                          costCoins: cost,
                          iconName: reward.iconName,
                          requireApproval: requireApproval,
                        ),
                      );
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: UltramanTheme.blue,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              child: Text(
                reward == null ? '上架奖励' : '保存修改',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: rewards.length,
        itemBuilder: (context, index) {
          final reward = rewards[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              onTap: () => _showRewardDialog(context, ref, reward: reward),
              leading: Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: UltramanTheme.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 26.r),
              ),
              title: Text(reward.title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              subtitle: Row(
                children: [
                  Text(
                    '${reward.costCoins} 币',
                    style: TextStyle(fontSize: 13.sp, color: UltramanTheme.gold, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8.w),
                  if (reward.requireApproval)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '需审核',
                        style: TextStyle(fontSize: 10.sp, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '免审核',
                        style: TextStyle(fontSize: 10.sp, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red, size: 22.r),
                tooltip: '下架',
                onPressed: () => _confirmDeleteReward(context, ref, reward.id),
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
        onPressed: () => _showRewardDialog(context, ref),
      ),
    );
  }
}
