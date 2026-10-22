import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/models/check_in_record.dart';
import '../../../data/models/child_profile.dart';
import '../../../data/models/reward_exchange.dart';
import '../../../data/models/task.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 审批历史记录页：展示家长所有已处理的审批（凭证审核 + 兑换审核）。
///
/// 数据来源就是持久化的 [CheckInRecord] 与 [RewardExchange]，审批通过/驳回
/// 后这些记录依然保存在本地（并随备份同步），这里按时间倒序完整展示，
/// 让家长能随时回看历史审批结果。
class ApprovalHistoryView extends ConsumerStatefulWidget {
  const ApprovalHistoryView({super.key});

  @override
  ConsumerState<ApprovalHistoryView> createState() =>
      _ApprovalHistoryViewState();
}

class _ApprovalHistoryViewState extends ConsumerState<ApprovalHistoryView> {
  String? _filterChildId; // null = 全部儿童

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    final children = family?.children ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('审批记录', style: TextStyle(fontSize: 20.sp)),
          backgroundColor: Colors.grey.shade900,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: UltramanTheme.gold,
            tabs: const [
              Tab(text: '凭证审核'),
              Tab(text: '兑换审核'),
            ],
          ),
        ),
        body: Column(
          children: [
            // 儿童筛选
            if (children.length > 1)
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
              child: TabBarView(
                children: [
                  _buildCheckInHistory(children),
                  _buildExchangeHistory(children),
                ],
              ),
            ),
          ],
        ),
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

  // ===== 凭证审核历史 =====
  Widget _buildCheckInHistory(List<ChildProfile> children) {
    final allRecords = ref.watch(checkInProvider);
    final tasks = ref.watch(taskProvider);

    final taskTitleById = <String, String>{
      for (final t in tasks) t.id: t.title,
    };

    // 只看已处理的记录（通过/驳回），待审核的由审批中心处理。
    var records = allRecords
        .where((r) => r.status == 'completed' || r.status == 'rejected')
        .toList();
    if (_filterChildId != null) {
      records =
          records.where((r) => r.childId == _filterChildId).toList();
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (records.isEmpty) {
      return const Center(
        child: Text('暂无凭证审批记录', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final r = records[index];
        final matched = children.where((c) => c.id == r.childId).toList();
        final childName = matched.isEmpty ? null : matched.first.name;
        return _CheckInHistoryCard(
          record: r,
          childName: childName ?? '未知英雄',
          taskTitle: taskTitleById[r.taskId] ?? '未知任务',
        );
      },
    );
  }

  // ===== 兑换审核历史 =====
  Widget _buildExchangeHistory(List<ChildProfile> children) {
    final allExchanges = ref.watch(exchangeProvider);

    var exchanges = allExchanges
        .where((e) =>
            e.status == 'approved' ||
            e.status == 'rejected' ||
            e.status == 'completed')
        .toList();
    if (_filterChildId != null) {
      exchanges =
          exchanges.where((e) => e.childId == _filterChildId).toList();
    }
    exchanges.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (exchanges.isEmpty) {
      return const Center(
        child: Text('暂无兑换审批记录', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: exchanges.length,
      itemBuilder: (context, index) {
        final e = exchanges[index];
        final matched = children.where((c) => c.id == e.childId).toList();
        final childName = matched.isEmpty ? null : matched.first.name;
        return _ExchangeHistoryCard(
          exchange: e,
          childName: childName ?? '未知英雄',
        );
      },
    );
  }
}

// ===== 凭证审核历史卡片 =====
class _CheckInHistoryCard extends StatelessWidget {
  final CheckInRecord record;
  final String childName;
  final String taskTitle;

  const _CheckInHistoryCard({
    required this.record,
    required this.childName,
    required this.taskTitle,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (record.status) {
      'completed' => (Colors.green, '已通过', Icons.check_circle),
      'rejected' => (Colors.red, '已驳回', Icons.cancel),
      _ => (Colors.grey, record.status, Icons.info),
    };

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    taskTitle,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(icon, color: color, size: 20.w),
                SizedBox(width: 4.w),
                Text(label, style: TextStyle(fontSize: 12.sp, color: color)),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              '$childName · ${record.date} · ${_time(record.createdAt)}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            SizedBox(height: 4.h),
            Text(
              '+${record.rewardCoins}币 / +${record.rewardExp}EXP',
              style: TextStyle(
                fontSize: 12.sp,
                color: UltramanTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 凭证照片预览
            if (record.proofImages.isNotEmpty)
              _buildProofPreview(record.proofImages),
          ],
        ),
      ),
    );
  }

  Widget _buildProofPreview(List<String> images) {
    final valid = images.where((p) => p.isNotEmpty && File(p).existsSync()).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: SizedBox(
        height: 80.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: valid.length,
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.only(right: 6.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Image.file(
                  File(valid[index]),
                  width: 80.w,
                  height: 80.h,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}

// ===== 兑换审核历史卡片 =====
class _ExchangeHistoryCard extends StatelessWidget {
  final RewardExchange exchange;
  final String childName;

  const _ExchangeHistoryCard({
    required this.exchange,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (exchange.status) {
      'completed' => (Colors.green, '已发放', Icons.check_circle),
      'approved' => (Colors.green, '已通过', Icons.check_circle),
      'rejected' => (Colors.red, '已驳回', Icons.cancel),
      _ => (Colors.grey, exchange.status, Icons.info),
    };

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: UltramanTheme.gold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.card_giftcard, color: UltramanTheme.gold, size: 26.r),
        ),
        title: Text(
          exchange.rewardTitle,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$childName · ${_time(exchange.createdAt)}',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '-${exchange.costCoins} 币',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 11.sp, color: color)),
          ],
        ),
      ),
    );
  }

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
