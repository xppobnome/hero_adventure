import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/utils/app_display.dart';
import '../../core/widgets/child_avatar.dart';
import '../../domain/providers/family_provider.dart';
import '../../domain/providers/theme_provider.dart';

/// 开屏启动页：展示奥特曼主题启动动画 + 应用名，短暂停留后自动进入主界面。
///
/// 若用户开启了「自定义显示」，则展示自定义头像与名字（儿童头像 / 昵称）。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.isNotEmpty == true ? family!.children.first : null;

    // 是否用自定义显示内容。
    final useCustom = AppDisplay.useCustomDisplay(storage);
    final appName = useCustom
        ? AppDisplay.resolveName(storage, child)
        : '小朋友冒险计划';
    final iconPath = useCustom
        ? AppDisplay.resolveIconPath(storage, child)
        : '';

    return Scaffold(
      backgroundColor: UltramanTheme.deepSpace,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 英雄盾牌图标 / 自定义头像 + 光环动画
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildIcon(useCustom, iconPath, appName),
              ),
            ),
            SizedBox(height: 28.h),
            FadeTransition(
              opacity: _fadeAnim,
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(height: 40.h),
            // 底部加载指示
            SizedBox(
              width: 24.w,
              height: 24.w,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: UltramanTheme.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 图标：自定义头像（若启用且有图片）→ 圆形头像；否则默认盾牌图标。
  Widget _buildIcon(bool useCustom, String iconPath, String appName) {
    if (useCustom &&
        iconPath.isNotEmpty &&
        File(iconPath).existsSync()) {
      return Container(
        width: 140.w,
        height: 140.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: UltramanTheme.blue.withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 4,
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
      width: 140.w,
      height: 140.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00A0E9), Color(0xFF0B1026)],
        ),
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: UltramanTheme.blue.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 72.r,
      ),
    );
  }
}
