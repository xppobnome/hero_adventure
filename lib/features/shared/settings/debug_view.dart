import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/models/child_profile.dart';
import '../../../domain/hero_system.dart' show expForLevel, levelFromExp;
import '../../../domain/providers/family_provider.dart';

/// 调试界面（隐藏入口：关于页连续点击软件版本 6 次进入）。
///
/// 提供开发 / 测试用的数据调整能力：
/// - 直接设置某个儿童的等级（折算经验值）与能量币数量；
/// - 查看当前各儿童的等级、经验值、能量币、出战英雄；
/// - 清空设备绑定 / 重置为未绑定状态。
class DebugView extends ConsumerStatefulWidget {
  const DebugView({super.key});

  @override
  ConsumerState<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends ConsumerState<DebugView> {
  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('调试模式', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.deepOrange.shade900,
      ),
      body: family == null
          ? const Center(child: Text('暂无家庭档案'))
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                Text(
                  '儿童数据调试',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                for (final child in family.children)
                  _DebugChildCard(childId: child.id, name: child.name),
                SizedBox(height: 24.h),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phonelink_erase, color: Colors.orange),
                    title: const Text('解除设备绑定'),
                    subtitle: const Text('将本机重置为未绑定（终端身份识别）状态'),
                    onTap: () {
                      ref.read(deviceRoleProvider.notifier).state = 'unbound';
                      ref.read(storageProvider).saveDeviceRole('unbound');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已解除设备绑定')),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// 单个儿童的调试卡片：展示当前数值 + 快速设置等级 / 能量币。
class _DebugChildCard extends ConsumerStatefulWidget {
  final String childId;
  final String name;
  const _DebugChildCard({required this.childId, required this.name});

  @override
  ConsumerState<_DebugChildCard> createState() => _DebugChildCardState();
}

class _DebugChildCardState extends ConsumerState<_DebugChildCard> {
  late final TextEditingController _levelController;
  late final TextEditingController _coinsController;

  @override
  void initState() {
    super.initState();
    final family = ref.read(familyProfileProvider);
    ChildProfile? child;
    for (final c in family?.children ?? const <ChildProfile>[]) {
      if (c.id == widget.childId) {
        child = c;
        break;
      }
    }
    final level = child == null ? 1 : levelFromExp(child.exp);
    _levelController = TextEditingController(text: '$level');
    _coinsController = TextEditingController(text: '${child?.coins ?? 0}');
  }

  @override
  void dispose() {
    _levelController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final level = int.tryParse(_levelController.text.trim()) ?? 1;
    final coins = int.tryParse(_coinsController.text.trim()) ?? 0;

    // 等级换算为经验值：达到该等级所需的最小累计经验。
    int exp = 0;
    for (int l = 2; l <= level; l++) {
      exp += expForLevel(l);
    }

    await ref
        .read(familyProfileProvider.notifier)
        .debugSetChildExpAndCoins(widget.childId, exp: exp, coins: coins);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.name}：已设置为 LV.$level / $coins 币')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    ChildProfile? child;
    for (final c in family?.children ?? const <ChildProfile>[]) {
      if (c.id == widget.childId) {
        child = c;
        break;
      }
    }
    final level = child == null ? 1 : levelFromExp(child.exp);

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '当前 LV.$level / ${child?.coins ?? 0} 币',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _levelController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '等级',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextField(
                    controller: _coinsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '能量币',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('应用设置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
