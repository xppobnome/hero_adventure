import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/reward_item.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/reward_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 儿童端奖励商城：用能量币兑换现实奖励，发起兑换申请。
class RewardShopView extends ConsumerWidget {
  final String childId;
  const RewardShopView({super.key, required this.childId});

  void _requestExchange(BuildContext context, WidgetRef ref, RewardItem reward) {
    final family = ref.read(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == childId);
    if (child == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('兑换「${reward.title}」', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text(
          '将消耗 ${reward.costCoins} 能量币，提交后需家长审核发放。\n\n当前余额：${child.coins} 能量币',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (child.coins < reward.costCoins) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('能量币不足，继续战斗吧！'), backgroundColor: Colors.red),
                );
                Navigator.pop(ctx);
                return;
              }
              ref.read(exchangeProvider.notifier).requestExchange(
                    childId: childId,
                    rewardId: reward.id,
                    rewardTitle: reward.title,
                    costCoins: reward.costCoins,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('兑换申请已提交，等待家长审核', style: TextStyle(fontSize: 14.sp)), backgroundColor: UltramanTheme.blue),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: UltramanTheme.blue),
            child: const Text('确认兑换', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardProvider);
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == childId);

    return Scaffold(
      appBar: AppBar(
        title: Text('能量兑换站', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: UltramanTheme.deepSpace,
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Text(
                '余额: ${child?.coins ?? 0} 币',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: rewards.isEmpty
            ? const Center(child: Text('商城暂未上架奖励'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: GridView.builder(
                  padding: EdgeInsets.all(16.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.w,
                    // 手机端格子更高，避免卡片内 Column 内容溢出
                    childAspectRatio: 0.78,
                  ),
                  itemCount: rewards.length,
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    final affordable = (child?.coins ?? 0) >= reward.costCoins;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: UltramanTheme.gold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 34.r),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              reward.title,
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '${reward.costCoins} 能量币',
                              style: TextStyle(fontSize: 14.sp, color: UltramanTheme.gold, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8.h),
                            ElevatedButton(
                              onPressed: () => _requestExchange(context, ref, reward),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: affordable ? UltramanTheme.blue : Colors.grey,
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                minimumSize: Size.zero,
                              ),
                              child: Text('兑换', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                            ),
                          ],
                        ),
                      ),
                    );
              },
            ),
          ),
        ),
      ),
    );
  }
}
