import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/utils/app_display.dart';
import '../../../core/utils/url_opener.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import 'debug_view.dart';

/// 「关于」页面：展示软件信息、版本号、软件介绍，并提供跳转 GitHub 项目入口。
///
/// 若用户开启了「自定义显示」，图标与名字展示自定义头像与昵称。
class AboutView extends ConsumerStatefulWidget {
  const AboutView({super.key});

  @override
  ConsumerState<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends ConsumerState<AboutView> {
  String _version = '1.0.0';
  String _buildNumber = '1';
  int _versionTapCount = 0; // 连续点击软件版本的计数（6 次进入调试模式）

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      // 读取失败时保留默认值（1.0.0），不阻塞页面。
    }
  }

  Future<void> _openGithub() async {
    const url = 'https://github.com/xppobnome/hero_adventure';
    await UrlOpener.open(url, context: context);
  }

  /// 图标：自定义头像（若启用且有图片）→ 圆形头像；否则默认应用图标 icon.png。
  Widget _buildIcon(bool useCustom, String iconPath, String appName) {
    if (useCustom && iconPath.isNotEmpty && File(iconPath).existsSync()) {
      return Container(
        width: 96.w,
        height: 96.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.file(
            File(iconPath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _defaultIcon(),
          ),
        ),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() {
    return Container(
      width: 96.w,
      height: 96.w,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _fallbackShieldIcon(),
        ),
      ),
    );
  }

  Widget _fallbackShieldIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00A0E9), Color(0xFF0B1026)],
        ),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 56.r,
      ),
    );
  }

  /// 连续点击软件版本 6 次进入调试模式。
  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 6) {
      _versionTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.isNotEmpty == true ? family!.children.first : null;

    final useCustom = AppDisplay.useCustomDisplay(storage);
    final appName = useCustom
        ? AppDisplay.resolveName(storage, child)
        : '小朋友冒险计划';
    final iconPath = useCustom
        ? AppDisplay.resolveIconPath(storage, child)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('关于', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== 应用图标 + 名称 =====
            Center(
              child: Column(
                children: [
                  _buildIcon(useCustom, iconPath, appName),
                  SizedBox(height: 16.h),
                  Text(
                    appName,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // ===== 版本信息 =====
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Color(0xFF00A0E9)),
                    title: const Text('软件版本'),
                    trailing: Text(
                      _version.isEmpty
                          ? '读取中…'
                          : (_buildNumber.isEmpty
                              ? _version
                              : '$_version (build $_buildNumber)'),
                      style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
                    ),
                    onTap: _onVersionTap,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.rocket_launch, color: Colors.orange),
                    title: const Text('软件类型'),
                    trailing: Text(
                      '儿童习惯打卡应用',
                      style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // ===== 软件介绍 =====
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '软件介绍',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '「小朋友冒险计划」是一款面向家庭的儿童习惯养成打卡应用，'
                      '以奥特曼「光之守护」主题打造。\n\n'
                      '家长可以下达防卫任务（学习、生活、锻炼等），孩子完成打卡'
                      '即获得经验与能量币，解锁更多英雄、兑换奖励，在闯关式'
                      '地图中一步步养成良好习惯。\n\n'
                      '支持多设备面对面传输、WebDAV 云端同步与备份，'
                      '数据安全可控，家长可通过 PIN 码守护儿童设备。',
                      style: TextStyle(
                        fontSize: 14.sp,
                        height: 1.6,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32.h),

            // ===== 开源项目入口 =====
            ElevatedButton.icon(
              onPressed: _openGithub,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF24292F),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: const Icon(Icons.code),
              label: Text(
                '查看开源项目 (GitHub)',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                'github.com/xppobnome/hero_adventure',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
              ),
            ),

            SizedBox(height: 32.h),
            Center(
              child: Text(
                '愿每一位小英雄都能成长为光',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: UltramanTheme.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
