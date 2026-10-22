import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/models/child_profile.dart';
import '../../../domain/hero_system.dart'
    show expForLevel, levelFromExp, maxLevel, heroCatalog;
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 调试界面（隐藏入口：关于页连续点击软件版本 6 次进入）。
///
/// 提供开发 / 测试用的数据调整能力：
/// - 直接设置某个儿童的等级（折算经验值）与能量币数量；
/// - 一键解锁全部英雄（设为满级）；
/// - 查看当前各儿童的等级、经验值、能量币、出战英雄、英雄解锁进度；
/// - 清空设备绑定 / 重置为未绑定状态；
/// - 一键复原（恢复到进入调试模式之前的状态）。
class DebugView extends ConsumerStatefulWidget {
  const DebugView({super.key});

  @override
  ConsumerState<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends ConsumerState<DebugView> {
  @override
  void initState() {
    super.initState();
    // 进入调试模式时保存一份「进入前」的家庭档案快照，供一键复原使用。
    _saveSnapshot();
  }

  Future<void> _saveSnapshot() async {
    final storage = ref.read(storageProvider);
    final family = ref.read(familyProfileProvider);
    if (family == null) return;
    await storage.saveDebugSnapshot(family, storage.getDeviceRole());
  }

  /// 一键复原：恢复到进入调试模式之前的状态。
  Future<void> _restoreSnapshot() async {
    final storage = ref.read(storageProvider);
    if (!storage.hasDebugSnapshot()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可复原的快照')),
      );
      return;
    }

    // 先读取快照中的设备角色（恢复后快照会被清空，需提前取）。
    final role = storage.getDebugSnapshotDeviceRole();

    // 恢复家庭档案 + 设备角色。
    await ref.read(familyProfileProvider.notifier).debugRestoreFromSnapshot();
    ref.read(deviceRoleProvider.notifier).state = role;
    await storage.saveDeviceRole(role);

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已一键复原到调试前的状态')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    final storage = ref.watch(storageProvider);
    final hasSnapshot = storage.hasDebugSnapshot();

    return Scaffold(
      appBar: AppBar(
        title: Text('调试模式', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: family == null
          ? const Center(child: Text('暂无家庭档案'))
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _buildBanner(),
                SizedBox(height: 16.h),
                Text(
                  '儿童数据调试',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                for (final child in family.children)
                  _DebugChildCard(childId: child.id, name: child.name),
                SizedBox(height: 24.h),
                _buildDeviceCard(),
                SizedBox(height: 12.h),
                _buildRestoreCard(hasSnapshot),
                SizedBox(height: 24.h),
              ],
            ),
    );
  }

  /// 顶部提示横幅。
  Widget _buildBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: UltramanTheme.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: UltramanTheme.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.build, color: UltramanTheme.blue, size: 20.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '调试模式仅用于开发测试，修改的数据会影响正式进度。'
              '建议修改前使用「一键复原」保存当前状态。',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  /// 设备绑定调试卡片。
  Widget _buildDeviceCard() {
    return Card(
      child: ListTile(
        leading: Icon(Icons.phonelink_erase, color: UltramanTheme.blue),
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
    );
  }

  /// 一键复原卡片。
  Widget _buildRestoreCard(bool hasSnapshot) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.restore,
          color: hasSnapshot ? UltramanTheme.blue : Colors.grey.shade400,
        ),
        title: const Text('一键复原'),
        subtitle: Text(
          hasSnapshot
              ? '恢复到进入调试模式之前的状态（等级、金币、出战英雄、设备绑定）'
              : '暂无快照（进入本页时应已自动保存）',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: hasSnapshot ? _restoreSnapshot : null,
      ),
    );
  }
}

/// 单个儿童的调试卡片：展示当前数值 + 快速设置等级 / 能量币 + 解锁全部英雄。
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

  /// 一键解锁全部英雄（设为满级）。
  Future<void> _unlockAllHeroes() async {
    await ref
        .read(familyProfileProvider.notifier)
        .debugUnlockAllHeroes(widget.childId);

    if (!mounted) return;
    setState(() {
      _levelController.text = '$maxLevel';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.name}：已解锁全部英雄（满级 LV.$maxLevel）')),
    );
  }

  /// 重置为 1 级 + 0 金币。
  Future<void> _reset() async {
    await ref
        .read(familyProfileProvider.notifier)
        .debugSetChildExpAndCoins(widget.childId, exp: 0, coins: 0);

    if (!mounted) return;
    setState(() {
      _levelController.text = '1';
      _coinsController.text = '0';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.name}：已重置为 LV.1 / 0 币')),
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
    final currentHeroId = child?.currentHeroId ?? 'ace';
    // 统计已解锁英雄数量。
    final unlockedCount =
        heroCatalog.where((h) => level >= h.unlockLevel).length;

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
                  'LV.$level / ${child?.coins ?? 0} 币',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              '经验 ${child?.exp ?? 0} · 出战 $currentHeroId · '
              '已解锁英雄 $unlockedCount/${heroCatalog.length}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
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
                  backgroundColor: UltramanTheme.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _unlockAllHeroes,
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('解锁全部英雄'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UltramanTheme.blue,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('重置为 1 级'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UltramanTheme.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
