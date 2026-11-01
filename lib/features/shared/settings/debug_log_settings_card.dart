import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/providers/family_provider.dart';

/// 「开启日志」设置卡片：控制全局详细日志开关。
///
/// 开启后，应用会把关键流程（模型下载、TTS 合成、播放等）写入本地日志文件，
/// 保存到手机公共「下载」目录，方便用户直接找到后发给开发者排查问题。
class DebugLogSettingsCard extends ConsumerStatefulWidget {
  const DebugLogSettingsCard({super.key});

  @override
  ConsumerState<DebugLogSettingsCard> createState() =>
      _DebugLogSettingsCardState();
}

class _DebugLogSettingsCardState extends ConsumerState<DebugLogSettingsCard> {
  @override
  Widget build(BuildContext context) {
    final enabled = ref.read(storageProvider).getDebugLogEnabled();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 4.h,
            ),
            secondary: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bug_report, color: Colors.teal, size: 24.r),
            ),
            title: Text(
              '开启日志',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '开启后记录语音下载 / 发音等详细日志到本地文件，'
              '用于排查问题，排查完建议关闭',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            value: enabled,
            activeColor: Colors.teal,
            onChanged: (v) async {
              await ref.read(storageProvider).setDebugLogEnabled(v);
              AppLogger.enabled = v;
              if (v) {
                // 开启时先初始化日志文件，拿到真实路径。
                await AppLogger.ensureLogFile();
              }
              if (!mounted) return;
              setState(() {});
              AppLogger.d('Settings', '日志开关切换为 $v');
              if (v) {
                _showLogPathHint();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('日志已关闭'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          // 开启状态下显示日志文件保存位置说明。
          if (enabled)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '日志文件保存在手机「下载 / Download」目录，'
                  '文件名以 hero_adventure_log 开头。排查问题时，'
                  '请把该目录下最新的日志文件发给开发者。',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 开启日志后弹出路径提示。
  void _showLogPathHint() {
    // 触发日志文件创建（懒初始化），拿到真实路径后提示。
    AppLogger.d('Settings', '日志已开启，开始记录');
    final path = AppLogger.logFilePath;
    final hint = path != null && path.isNotEmpty
        ? '日志已开启\n文件保存在：\n$path'
        : '日志已开启\n文件保存在手机「下载 / Download」目录，'
              '文件名以 hero_adventure_log 开头';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hint), duration: const Duration(seconds: 5)),
    );
  }
}
