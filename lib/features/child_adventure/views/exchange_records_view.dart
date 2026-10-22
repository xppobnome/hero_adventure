import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../domain/providers/exchange_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 兑换记录页：展示某儿童的全部兑换流水（日期时间、奖励、扣币、状态）。
class ExchangeRecordsView extends ConsumerWidget {
  final String childId;
  const ExchangeRecordsView({super.key, required this.childId});

  String _formatTime(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '${t.year}-$m-$d $h:$min';
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'completed':
        return ('已发放', Colors.green);
      case 'approved':
        return ('已发放', Colors.green);
      case 'rejected':
        return ('已驳回·已退回', Colors.red);
      default:
        return ('待审核', UltramanTheme.gold);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchanges = ref.watch(exchangeProvider);
    final mine = exchanges.where((e) => e.childId == childId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('兑换记录', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: UltramanStarfield()),
          mine.isEmpty
              ? const Center(
                  child: Text('暂无兑换记录',
                      style: TextStyle(color: Colors.white70)),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: mine.length,
                      itemBuilder: (context, index) {
                        final e = mine[index];
                        final (label, color) = _statusInfo(e.status);
                        return Card(
                          margin: EdgeInsets.only(bottom: 12.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 10.h),
                            leading: Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color:
                                    UltramanTheme.gold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.card_giftcard,
                                  color: UltramanTheme.gold, size: 26.r),
                            ),
                            title: Text(
                              e.rewardTitle,
                              style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _formatTime(e.createdAt),
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade600),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '-${e.costCoins} 币',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  label,
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
