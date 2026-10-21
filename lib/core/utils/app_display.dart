import '../../data/models/child_profile.dart';
import '../../data/repositories/local_storage_repo.dart';

/// 解析「应用显示名与显示图标」的统一逻辑。
///
/// 供启动图（SplashScreen）、关于页（AboutView）、桌面快捷方式共用，
/// 保证三处显示的自定义头像与名字一致。
///
/// 规则：
/// - 名字：若开启「用昵称」→ 取第一个儿童昵称拼「英雄闯关冒险」；
///   否则取自定义名字；否则用默认「小朋友冒险计划」。
/// - 图标：优先自定义图标路径；否则若开启「用头像」取第一个儿童头像；
///   否则为空（用默认图标）。
class AppDisplay {
  AppDisplay._();

  /// 解析显示名。
  static String resolveName(LocalStorageRepo storage, ChildProfile? child) {
    if (storage.getShortcutUseName()) {
      final name = (child != null && child.name.isNotEmpty) ? child.name : '小朋友';
      return '$name英雄闯关冒险';
    }
    final custom = storage.getShortcutCustomName();
    if (custom.isNotEmpty) return custom;
    return '小朋友冒险计划';
  }

  /// 解析显示图标本地路径（空表示用默认图标）。
  static String resolveIconPath(LocalStorageRepo storage, ChildProfile? child) {
    final custom = storage.getShortcutIconPath();
    if (custom.isNotEmpty) return custom;
    if (storage.getShortcutUseAvatar() &&
        child != null &&
        child.avatarImage.isNotEmpty) {
      return child.avatarImage;
    }
    return '';
  }

  /// 是否启用了自定义显示（启动图/关于页是否用自定义内容）。
  static bool useCustomDisplay(LocalStorageRepo storage) {
    return storage.getUseCustomAppDisplay();
  }
}
