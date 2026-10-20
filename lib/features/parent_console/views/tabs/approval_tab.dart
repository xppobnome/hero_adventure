import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/models/check_in_record.dart';
import '../../../../data/models/reward_exchange.dart';
import '../../../../data/models/task.dart';
import '../../../../domain/providers/check_in_provider.dart';
import '../../../../domain/providers/exchange_provider.dart';
import '../../../../domain/providers/family_provider.dart';
import '../../../../domain/providers/task_provider.dart';
import '../../../../domain/providers/theme_provider.dart';

/// 家长端审批中心。
///
/// 包含两个审批流：
/// 1. 拍照打卡凭证审核 (pending -> completed / rejected)
/// 2. 奖励兑换申请审批 (requested -> approved / rejected)
class ApprovalTab extends ConsumerWidget {
  const ApprovalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIns = ref.watch(checkInProvider);
    final exchanges = ref.watch(exchangeProvider);

    final pendingCheckIns = checkIns.where((r) => r.status == 'pending').toList();
    final pendingExchanges = exchanges.where((e) => e.status == 'requested').toList();

    final totalPending = pendingCheckIns.length + pendingExchanges.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: Colors.grey.shade100,
              child: TabBar(
                labelColor: UltramanTheme.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: UltramanTheme.blue,
                tabs: [
                  Tab(text: '凭证审核 (${pendingCheckIns.length})'),
                  Tab(text: '兑换审批 (${pendingExchanges.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCheckInApproval(context, ref, pendingCheckIns),
                  _buildExchangeApproval(context, ref, pendingExchanges),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 凭证审核 =====
  Widget _buildCheckInApproval(BuildContext context, WidgetRef ref, List<CheckInRecord> records) {
    if (records.isEmpty) {
      return const Center(child: Text('暂无待审核凭证', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final tasks = ref.read(taskProvider);
        final task = _findTask(tasks, record.taskId);
        final child = _childName(ref, record.childId);
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${child} · ${task?.title ?? '未知任务'}',
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(record.date, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                  ],
                ),
                SizedBox(height: 8.h),
                if (record.proofImage != null && File(record.proofImage!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      File(record.proofImage!),
                      height: 120.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 80.h,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                  ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => ref.read(checkInProvider.notifier).review(record.id, false),
                      child: const Text('驳回', style: TextStyle(color: Colors.red)),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: () {
                        // 审核通过：下发奖励
                        ref.read(familyProfileProvider.notifier).grantReward(
                              record.childId,
                              record.rewardExp,
                              record.rewardCoins,
                            );
                        ref.read(checkInProvider.notifier).review(record.id, true);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text('通过并发放', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== 兑换审批 =====
  Widget _buildExchangeApproval(BuildContext context, WidgetRef ref, List<RewardExchange> exchanges) {
    if (exchanges.isEmpty) {
      return const Center(child: Text('暂无待审批兑换', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: exchanges.length,
      itemBuilder: (context, index) {
        final exchange = exchanges[index];
        final child = _childName(ref, exchange.childId);
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            leading: Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 32.r),
            title: Text(exchange.rewardTitle, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
            subtitle: Text('$child 申请 · 消耗 ${exchange.costCoins} 币', style: TextStyle(fontSize: 13.sp)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red, size: 24.r),
                  onPressed: () => ref.read(exchangeProvider.notifier).review(exchange.id, false),
                ),
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green, size: 24.r),
                  onPressed: () {
                    // 审核通过：扣除能量币并发放
                    ref.read(familyProfileProvider.notifier).spendCoins(
                          exchange.childId,
                          exchange.costCoins,
                        );
                    ref.read(exchangeProvider.notifier).review(exchange.id, true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _childName(WidgetRef ref, String childId) {
    final family = ref.read(familyProfileProvider);
    if (family == null) return '未知英雄';
    for (final c in family.children) {
      if (c.id == childId) return c.name;
    }
    return '未知英雄';
  }

  /// 按 id 查找任务，找不到返回 null。
  Task? _findTask(List<Task> tasks, String taskId) {
    for (final t in tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }
}
