import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../domain/providers/family_provider.dart';
import '../../child_adventure/views/child_adventure_view.dart';
import '../../sync/views/sync_dashboard_view.dart';
import 'pin_code_view.dart';

class RoleSelectionView extends ConsumerWidget {
  const RoleSelectionView({super.key});

  void _showBindDialog(BuildContext context, WidgetRef ref, String childId, String childName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设备终端配置', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text('要将这台设备固定为 [$childName] 的专属打卡终端吗？\n\n固定后，每次打开应用将直接进入 $childName 的防卫地图。', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 仅临时进入，不绑定
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChildAdventureView(childId: childId)));
            },
            child: const Text('仅本次进入', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // 执行设备绑定
              ref.read(deviceRoleProvider.notifier).state = childId;
              ref.read(storageProvider).saveDeviceRole(childId);
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChildAdventureView(childId: childId)));
            },
            child: const Text('设为专属终端'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProfileProvider);
    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('终端身份识别'),
        actions: [
          IconButton(
            icon: Icon(Icons.cloud_sync, size: 24.r),
            tooltip: '云端同步',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncDashboardView())),
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Text('请选择要进入的终端身份', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 24.h),
            Expanded(
              child: family == null || family.children.isEmpty
                  ? Center(child: Text('暂无小英雄档案', style: TextStyle(fontSize: 16.sp)))
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 4 : 2,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.w,
                ),
                itemCount: family.children.length,
                itemBuilder: (context, index) {
                  final child = family.children[index];
                  return InkWell(
                    onTap: () => _showBindDialog(context, ref, child.id, child.name),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChildAvatar(
                            avatarImage: child.avatarImage,
                            name: child.name,
                            size: 80.r,
                          ),
                          SizedBox(height: 12.h),
                          Text(child.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4.h),
                          Text('LV. ${child.exp ~/ 100 + 1}', style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16.h),
            SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinCodeView())),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56.h),
                  backgroundColor: Colors.grey.shade900, // 家长端用深色区分
                ),
                icon: const Icon(Icons.security),
                label: Text('进入宇宙警备队 (家长控制台)', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}