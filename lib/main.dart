import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 引入本地化
import 'core/utils/audio_manager.dart';
import 'core/utils/data_sync_checker.dart';
import 'core/utils/update_service.dart';
import 'data/repositories/local_storage_repo.dart';
import 'data/repositories/sync_repo.dart';
import 'domain/providers/family_provider.dart';
import 'domain/providers/theme_provider.dart';
import 'domain/providers/task_provider.dart';
import 'domain/providers/reward_provider.dart';
import 'domain/providers/check_in_provider.dart';
import 'domain/providers/exchange_provider.dart';

import 'features/auth/views/family_setup_view.dart';
import 'features/auth/views/role_selection_view.dart';
import 'features/child_adventure/views/child_adventure_view.dart'; // 引入儿童端
import 'features/parent_console/views/parent_console_view.dart'; // 引入家长端
import 'features/splash/splash_screen.dart';

// 允许忽略所有自签名 SSL 证书的全局类
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 边缘到边缘 + 导航栏颜色与 App 背景一致：
  // 透明导航栏在部分机型会渲染成黑边，因此直接把导航栏背景色设为
  // App 全局背景色 (scaffoldBackgroundColor 0xFFF5F5F5)，三金刚 / 小白条
  // 区域与页面底部颜色保持一致。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF5F5F5),
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  HttpOverrides.global = MyHttpOverrides();
  final storageRepo = LocalStorageRepo();
  await storageRepo.init();

  // 设置最高刷新率：让 App 使用手机屏幕支持的最高刷新率 (如 120/165Hz)。
  // 失败时静默降级 (部分设备/平台不支持时不影响启动)。
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // 忽略：不支持高刷新率设置的平台 (如部分 Web/桌面) 会抛出异常，不影响运行
  }

  // 提前初始化音频会话，确保选择英雄 / 打卡时的音效播放稳定可靠
  // (Android 上 just_audio 播放音频前必须先配置 AudioSession)。
  await AudioManager().ensureSession();

  runApp(
    ProviderScope(
      overrides: [storageProvider.overrideWithValue(storageRepo)],
      child: HeroAdventureApp(designSize: _resolveDesignSize(storageRepo)),
    ),
  );
}

/// 根据设备物理尺寸 + 用户「界面样式」设置解析适配基准。
///
/// - 手机 / 窄屏（短边 < 600dp）：使用 375x812 设计稿（缩放 ≈1）。
/// - 平板 / 宽屏：使用 iPad 竖屏基准 768x1024，使 screenutil 缩放不再按
///   宽度放大 3 倍以上；平板竖屏时缩放 ≈1，横屏时约 1.6 倍（可接受）。
///
/// 说明：designSize 用固定基准而非物理尺寸，避免屏幕旋转时基准剧烈变化
/// （横屏 1280 ↔ 竖屏 800）导致缩放忽大忽小。
Size _resolveDesignSize(LocalStorageRepo storage) {
  // 用户显式选择优先。
  final mode = storage.getUiMode();
  final physical = _physicalLogicalSize();

  if (mode == 'phone') return const Size(375, 812);
  if (mode == 'tablet') return const Size(768, 1024);

  // 'auto'：按物理尺寸判断。
  if (physical != null && physical.shortSide >= 600) {
    return const Size(768, 1024);
  }
  return const Size(375, 812);
}

/// 读取物理逻辑尺寸（宽、高、短边）；拿不到时返回 null。
({double width, double height, double shortSide})? _physicalLogicalSize() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return null;
  final view = views.first;
  final physical = view.physicalSize;
  final ratio = view.devicePixelRatio;
  final w = physical.width / ratio;
  final h = physical.height / ratio;
  return (width: w, height: h, shortSide: w < h ? w : h);
}

class HeroAdventureApp extends StatelessWidget {
  const HeroAdventureApp({super.key, required this.designSize});

  /// 屏幕适配设计基准：手机 375x812，平板/宽屏用更大的基准，避免
  /// screenutil 按宽度比例把 .w/.sp/.h 放大 3 倍以上导致内容溢出。
  final Size designSize;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: '儿童英雄闯关冒险',
          // 使用奥特曼主题统一配色
          theme: UltramanTheme.buildTheme(),
          // 【解决全部底层英文问题】：强制配置中文本地化 (如 Stepper, Dialog 等默认组件)
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          home:  SplashGate(),
        );
      },
    );
  }
}

/// 开屏过渡：先展示启动动画，短暂停留后自动切换到主界面。
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // 开屏停留约 2.4 秒后进入主界面（配合启动音效与华丽特效动画时长）。
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();
    return const InitialRouteWrapper();
  }
}

class InitialRouteWrapper extends ConsumerStatefulWidget {
  const InitialRouteWrapper({super.key});

  @override
  ConsumerState<InitialRouteWrapper> createState() =>
      _InitialRouteWrapperState();
}class _InitialRouteWrapperState extends ConsumerState<InitialRouteWrapper> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // 进入/退出时同步：
    // - onResume：应用从后台恢复，刷新所有数据 Provider，对齐跨端最新状态
    // - onPause/onDetach：应用退到后台或即将销毁，触发本地数据落盘
    _lifecycleListener = AppLifecycleListener(
      onResume: _syncOnResume,
      onPause: _syncOnPause,
      onDetach: _syncOnPause,
    );
    // 启动后延迟执行自动检查（更新版本 / 云端数据版本），
    // 等首帧渲染完、家庭档案就绪后再触发，避免启动时阻塞或弹窗过早。
    WidgetsBinding.instance.addPostFrameCallback((_) => _startupChecks());
  }

  /// 启动自动检查：应用更新 + WebDAV 云端数据版本（均尊重各自开关）。
  Future<void> _startupChecks() async {
    final familyProfile = ref.read(familyProfileProvider);
    if (familyProfile == null) return; // 首次安装未完成引导，跳过检查

    if (!mounted) return;
    final storage = ref.read(storageProvider);
    await UpdateService.checkOnStartup(context, storage);
    if (!mounted) return;
    await DataSyncChecker.checkOnStartup(context, storage);
  }

  void _syncOnResume() {
    if (!mounted) return;
    // 本地 Hive 数据每次写入已实时持久化，此处刷新内存态以对齐
    // 进入应用时重新加载全部数据 Provider，保证跨入口状态一致。
    ref.invalidate(familyProfileProvider);
    ref.invalidate(taskProvider);
    ref.invalidate(rewardProvider);
    ref.invalidate(checkInProvider);
    ref.invalidate(exchangeProvider);
  }

  void _syncOnPause() {
    // 退出/切后台时确保数据已持久化。
    // 各 Provider 的写操作均通过 LocalStorageRepo 同步落盘到 Hive，
    // 这里额外触发一次刷新，保证未写入的待处理状态被安全保存。
    if (!mounted) return;
    ref.invalidate(familyProfileProvider);

    // 「退出前上传数据」开关开启且已绑定 WebDAV 时，退出前把最新数据备份到云端。
    final storage = ref.read(storageProvider);
    if (storage.getUploadOnExit() && storage.hasWebDavConfig()) {
      _uploadBeforeExit(storage);
    }
  }

  /// 退出前上传数据到云端（静默执行，失败不打扰用户）。
  Future<void> _uploadBeforeExit(LocalStorageRepo storage) async {
    try {
      final (url, user, pwd, dir) = storage.getWebDavConfig();
      if (url.isEmpty) return;
      final syncRepo = SyncRepo(storage);
      await syncRepo.backupToWebDav(
        url: url,
        username: user,
        password: pwd,
        directory: dir,
      );
      debugPrint('[退出上传] 已备份最新数据到 WebDAV');
    } catch (e) {
      debugPrint('[退出上传] 上传失败：$e');
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyProfile = ref.watch(familyProfileProvider);
    final deviceRole = ref.watch(deviceRoleProvider);

    debugPrint('[路由] InitialRouteWrapper build: deviceRole=$deviceRole, hasFamily=${familyProfile != null}');

    // 1. 无数据，进入初始化
    if (familyProfile == null) return const FamilySetupView();

    // 2. 检查设备绑定状态：
    //    - 家长设备：直接进入家长控制台 (无需每次输 PIN)
    //    - 儿童专属设备：直接进入该儿童的防卫地图
    if (deviceRole == 'parent') {
      return const ParentConsoleView();
    }
    if (deviceRole != 'unbound') {
      final childExists = familyProfile.children.any((c) => c.id == deviceRole);
      if (childExists) {
        return ChildAdventureView(childId: deviceRole);
      }
    }

    // 3. 未绑定，进入角色选择（绑定中心）
    return const RoleSelectionView();
  }
}
