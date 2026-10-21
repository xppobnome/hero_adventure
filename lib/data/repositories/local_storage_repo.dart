import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/utils/image_compressor.dart';
import '../models/child_profile.dart';
import '../models/family_profile.dart';
import '../models/task.dart';
import '../models/reward_item.dart';
import '../models/check_in_record.dart';
import '../models/reward_exchange.dart';

class LocalStorageRepo {
  static const String boxName = 'hero_data_box';
  static const String keyFamilyProfile = 'family_profile';
  static const String keyTasks = 'tasks';
  static const String keyRewards = 'rewards';
  static const String keyCheckIns = 'check_in_records'; // 打卡记录
  static const String keyExchanges = 'reward_exchanges'; // 兑换申请

  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(boxName);
  }

  // ===== 家族档案存取 =====
  Future<void> saveFamilyProfile(FamilyProfile profile) async {
    await _box.put(keyFamilyProfile, jsonEncode(profile.toJson()));
  }

  FamilyProfile? getFamilyProfile() {
    final data = _box.get(keyFamilyProfile);
    if (data != null) {
      final Map<String, dynamic> json = jsonDecode(data);
      return FamilyProfile.fromJson(json);
    }
    return null;
  }

  // ===== 任务列表存取 =====
  Future<void> saveTasks(List<Task> tasks) async {
    final List<Map<String, dynamic>> jsonList = tasks
        .map((t) => t.toJson())
        .toList();
    await _box.put(keyTasks, jsonEncode(jsonList));
  }

  List<Task> getTasks() {
    final data = _box.get(keyTasks);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ===== 奖励商城存取 =====
  Future<void> saveRewards(List<RewardItem> rewards) async {
    final List<Map<String, dynamic>> jsonList = rewards
        .map((r) => r.toJson())
        .toList();
    await _box.put(keyRewards, jsonEncode(jsonList));
  }

  List<RewardItem> getRewards() {
    final data = _box.get(keyRewards);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((e) => RewardItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ===== 打卡记录存取 (本次新增) =====
  Future<void> saveCheckIns(List<CheckInRecord> records) async {
    final List<Map<String, dynamic>> jsonList = records
        .map((r) => r.toJson())
        .toList();
    await _box.put(keyCheckIns, jsonEncode(jsonList));
  }

  List<CheckInRecord> getCheckIns() {
    final data = _box.get(keyCheckIns);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((e) => CheckInRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ===== 兑换申请存取 (本次新增) =====
  Future<void> saveExchanges(List<RewardExchange> exchanges) async {
    final List<Map<String, dynamic>> jsonList = exchanges
        .map((e) => e.toJson())
        .toList();
    await _box.put(keyExchanges, jsonEncode(jsonList));
  }

  List<RewardExchange> getExchanges() {
    final data = _box.get(keyExchanges);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((e) => RewardExchange.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ===== 设备绑定存取 =====
  static const String keyDeviceRole = 'device_role';

  Future<void> saveDeviceRole(String role) async {
    await _box.put(keyDeviceRole, role);
  }

  // 返回: 'unbound' (未绑定), 'parent' (家长设备), 或者具体的 childId
  String getDeviceRole() {
    return _box.get(keyDeviceRole) ?? 'unbound';
  }

  // ===== 应用设置存取 (更新检查 / 数据版本检查 / WebDAV 配置) =====
  static const String keyUpdateAutoCheck = 'update_auto_check'; // 自动检查更新开关
  static const String keyUpdateIgnoredVersion =
      'update_ignored_version'; // 「下个版本提醒我」忽略的版本号
  static const String keyUpdatePermanentIgnored =
      'update_permanently_ignored'; // 永久忽略更新
  static const String keyUpdateSource =
      'update_source'; // 更新源：'github' / 'gitee'
  static const String keyWebDavUrl = 'webdav_url'; // WebDAV 地址
  static const String keyWebDavUser = 'webdav_user'; // WebDAV 账号
  static const String keyWebDavPwd = 'webdav_pwd'; // WebDAV 密码
  static const String keyWebDavDir =
      'webdav_dir'; // WebDAV 存储目录（默认 /HeroAdventure）
  static const String keyDataSyncAutoCheck =
      'datasync_auto_check'; // 启动时检查云端数据版本开关
  static const String keyLastSyncedUploadAt =
      'last_synced_upload_at'; // 本机最近一次同步的云端时间戳
  static const String keyUiMode =
      'ui_mode'; // 界面样式：'auto' / 'phone' / 'tablet'
  static const String keyShowNavLabels =
      'show_nav_labels'; // 家长菜单栏是否展示文字标签
  static const String keyUploadOnExit =
      'upload_on_exit'; // 退出前上传数据到云端（若已绑定 WebDAV）
  static const String keyForceSync =
      'force_sync_on_change'; // 打卡/兑换/审核等变更时强制同步到云端
  static const String keyShortcutUseAvatar =
      'shortcut_use_avatar'; // 桌面快捷方式是否用儿童头像作图标
  static const String keyShortcutUseName =
      'shortcut_use_name'; // 桌面快捷方式是否用儿童昵称作名字
  static const String keyShortcutCustomName =
      'shortcut_custom_name'; // 桌面快捷方式自定义名字
  static const String keyShortcutIconPath =
      'shortcut_icon_path'; // 桌面快捷方式自定义图标本地路径
  static const String keyUseCustomAppDisplay =
      'use_custom_app_display'; // 启动图/关于页是否显示自定义头像与名字

  bool getUpdateAutoCheck() =>
      _box.get(keyUpdateAutoCheck) as bool? ?? true; // 默认开启

  Future<void> setUpdateAutoCheck(bool value) =>
      _box.put(keyUpdateAutoCheck, value);

  String getUpdateIgnoredVersion() =>
      _box.get(keyUpdateIgnoredVersion) as String? ?? '';

  Future<void> setUpdateIgnoredVersion(String version) =>
      _box.put(keyUpdateIgnoredVersion, version);

  bool getUpdatePermanentIgnored() =>
      _box.get(keyUpdatePermanentIgnored) as bool? ?? false;

  Future<void> setUpdatePermanentIgnored(bool value) =>
      _box.put(keyUpdatePermanentIgnored, value);

  /// 更新源：'github'（默认）/ 'gitee'。
  String getUpdateSource() =>
      _box.get(keyUpdateSource) as String? ?? 'github';

  Future<void> setUpdateSource(String source) =>
      _box.put(keyUpdateSource, source);

  String getWebDavUrl() => _box.get(keyWebDavUrl) as String? ?? '';

  /// 默认存储目录。
  static const String defaultWebDavDir = '/HeroAdventure';

  Future<void> saveWebDavConfig({
    required String url,
    required String username,
    required String password,
    String? directory,
  }) async {
    await _box.put(keyWebDavUrl, url);
    await _box.put(keyWebDavUser, username);
    await _box.put(keyWebDavPwd, password);
    if (directory != null) {
      await _box.put(keyWebDavDir, directory);
    }
  }

  /// 是否已绑定 WebDAV（配置过有效地址即视为已绑定）。
  bool hasWebDavConfig() => getWebDavUrl().trim().isNotEmpty;

  /// 读取 WebDAV 配置：(url, username, password, directory)。
  (String, String, String, String) getWebDavConfig() {
    return (
      _box.get(keyWebDavUrl) as String? ?? '',
      _box.get(keyWebDavUser) as String? ?? '',
      _box.get(keyWebDavPwd) as String? ?? '',
      _box.get(keyWebDavDir) as String? ?? defaultWebDavDir,
    );
  }

  bool getDataSyncAutoCheck() =>
      _box.get(keyDataSyncAutoCheck) as bool? ?? true; // 默认开启

  Future<void> setDataSyncAutoCheck(bool value) =>
      _box.put(keyDataSyncAutoCheck, value);

  String getLastSyncedUploadAt() =>
      _box.get(keyLastSyncedUploadAt) as String? ?? '';

  Future<void> setLastSyncedUploadAt(String isoTime) =>
      _box.put(keyLastSyncedUploadAt, isoTime);

  /// 读取界面样式设置：'auto'（默认，按设备型号自动）/ 'phone' / 'tablet'。
  String getUiMode() => _box.get(keyUiMode) as String? ?? 'auto';

  Future<void> setUiMode(String mode) => _box.put(keyUiMode, mode);

  /// 家长菜单栏是否展示文字标签（默认展示）。
  bool getShowNavLabels() => _box.get(keyShowNavLabels) as bool? ?? true;

  Future<void> setShowNavLabels(bool value) =>
      _box.put(keyShowNavLabels, value);

  /// 退出前是否上传数据到云端（默认开启）。
  bool getUploadOnExit() => _box.get(keyUploadOnExit) as bool? ?? true;

  Future<void> setUploadOnExit(bool value) =>
      _box.put(keyUploadOnExit, value);

  /// 打卡/兑换/审核等变更时是否强制同步到云端（默认开启）。
  bool getForceSync() => _box.get(keyForceSync) as bool? ?? true;

  Future<void> setForceSync(bool value) => _box.put(keyForceSync, value);

  /// 桌面快捷方式：是否用儿童头像作图标（默认 false）。
  bool getShortcutUseAvatar() => _box.get(keyShortcutUseAvatar) as bool? ?? false;

  Future<void> setShortcutUseAvatar(bool value) =>
      _box.put(keyShortcutUseAvatar, value);

  /// 桌面快捷方式：是否用儿童昵称作名字（默认 false）。
  bool getShortcutUseName() => _box.get(keyShortcutUseName) as bool? ?? false;

  Future<void> setShortcutUseName(bool value) =>
      _box.put(keyShortcutUseName, value);

  /// 桌面快捷方式：自定义名字（默认空，空则用默认名）。
  String getShortcutCustomName() =>
      _box.get(keyShortcutCustomName) as String? ?? '';

  Future<void> setShortcutCustomName(String value) =>
      _box.put(keyShortcutCustomName, value);

  /// 桌面快捷方式：自定义图标本地路径（默认空，空则用默认/头像）。
  String getShortcutIconPath() =>
      _box.get(keyShortcutIconPath) as String? ?? '';

  Future<void> setShortcutIconPath(String value) =>
      _box.put(keyShortcutIconPath, value);

  /// 启动图/关于页是否显示自定义头像与名字（默认 false）。
  bool getUseCustomAppDisplay() =>
      _box.get(keyUseCustomAppDisplay) as bool? ?? false;

  Future<void> setUseCustomAppDisplay(bool value) =>
      _box.put(keyUseCustomAppDisplay, value);

  // ===== 全量快照 (供二维码/WebDAV/本地备份 同步) =====
  //
  // 快照中额外包含 images 字段：把本地图片（儿童头像 avatarImage、打卡凭证
  // proofImage）压缩为 base64 内嵌，使图片内容能随快照一起同步，而非仅同步
  // 一个换设备后失效的本地路径。三个同步通道共用此方法。
  Future<Map<String, dynamic>> buildSnapshot() async {
    final family = getFamilyProfile();
    final checkIns = getCheckIns();

    // 收集所有需要同步的图片路径。
    final imagePaths = <String>[];
    final children = family?.children ?? const <ChildProfile>[];
    for (final c in children) {
      if (c.avatarImage.isNotEmpty) imagePaths.add(c.avatarImage);
    }
    for (final c in checkIns) {
      final p = c.proofImage;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }

    // 去重后压缩成 base64，key 用原路径。
    final images = <String, String>{};
    for (final path in imagePaths.toSet()) {
      final base64 = await ImageCompressor.compressToBase64(path);
      if (base64 != null) {
        images[path] = base64;
      }
    }

    return {
      'family': family?.toJson(),
      'tasks': getTasks().map((t) => t.toJson()).toList(),
      'rewards': getRewards().map((r) => r.toJson()).toList(),
      'checkIns': checkIns.map((c) => c.toJson()).toList(),
      'exchanges': getExchanges().map((e) => e.toJson()).toList(),
      'images': images,
      // 设置与账号信息：WebDAV 配置、设备角色、各类开关等，一并备份，
      // 确保「换机 / 恢复」后无需重新配置。
      'settings': _buildSettingsSnapshot(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 构建「设置/账号」快照，包含 WebDAV 配置、设备角色、各开关。
  Map<String, dynamic> _buildSettingsSnapshot() {
    return {
      'webdav': {
        'url': getWebDavUrl(),
        'username': _box.get(keyWebDavUser) as String? ?? '',
        'password': _box.get(keyWebDavPwd) as String? ?? '',
        'directory': _box.get(keyWebDavDir) as String? ?? defaultWebDavDir,
      },
      'deviceRole': getDeviceRole(),
      'updateAutoCheck': getUpdateAutoCheck(),
      'updateIgnoredVersion': getUpdateIgnoredVersion(),
      'updatePermanentIgnored': getUpdatePermanentIgnored(),
      'updateSource': getUpdateSource(),
      'dataSyncAutoCheck': getDataSyncAutoCheck(),
      'uiMode': getUiMode(),
      'showNavLabels': getShowNavLabels(),
      'uploadOnExit': getUploadOnExit(),
      'forceSync': getForceSync(),
      'shortcutUseAvatar': getShortcutUseAvatar(),
      'shortcutUseName': getShortcutUseName(),
      'shortcutCustomName': getShortcutCustomName(),
      'shortcutIconPath': getShortcutIconPath(),
      'useCustomAppDisplay': getUseCustomAppDisplay(),
    };
  }

  /// 从快照 Map 恢复全量数据。
  Future<void> restoreSnapshot(Map<String, dynamic> snapshot) async {
    // 先还原图片：把快照中的 base64 图片写回本地文件，
    // 得到「原路径 → 新路径」的映射，用于更新 family/checkIns 里的图片字段。
    final imageMap = await _restoreImages(snapshot);

    if (snapshot['family'] != null) {
      var family = FamilyProfile.fromJson(
        Map<String, dynamic>.from(snapshot['family']),
      );
      // 更新每个儿童的头像路径（如果该图片被还原到了新位置）。
      if (imageMap.isNotEmpty) {
        family = FamilyProfile(
          familyId: family.familyId,
          currentTheme: family.currentTheme,
          pinCode: family.pinCode,
          children: family.children.map((c) {
            final newPath = imageMap[c.avatarImage];
            return newPath == null ? c : c.copyWith(avatarImage: newPath);
          }).toList(),
        );
      }
      await saveFamilyProfile(family);
    }
    if (snapshot['tasks'] != null) {
      await saveTasks(
        (snapshot['tasks'] as List)
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    if (snapshot['rewards'] != null) {
      await saveRewards(
        (snapshot['rewards'] as List)
            .map((e) => RewardItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    if (snapshot['checkIns'] != null) {
      final records = (snapshot['checkIns'] as List)
          .map((e) => CheckInRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // 更新打卡凭证图片路径。
      final restored = imageMap.isNotEmpty
          ? records.map((r) {
              final old = r.proofImage;
              final newPath = old == null ? null : imageMap[old];
              return newPath == null ? r : r.copyWith(proofImage: newPath);
            }).toList()
          : records;
      await saveCheckIns(restored);
    }
    if (snapshot['exchanges'] != null) {
      await saveExchanges(
        (snapshot['exchanges'] as List)
            .map((e) => RewardExchange.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    // 恢复设置与账号信息（WebDAV 配置、设备角色、各开关）。
    if (snapshot['settings'] != null) {
      await _restoreSettings(Map<String, dynamic>.from(snapshot['settings']));
    }
  }

  /// 从快照恢复设置与账号信息。
  ///
  /// 说明：设备角色（deviceRole）不强制覆盖，避免「导入他人数据」时本机
  /// 意外变成对方的专属终端；仅在快照中角色为 'unbound'/'parent' 这类
  /// 明确值且本地尚未绑定时才写入。WebDAV 配置与各开关则直接覆盖。
  Future<void> _restoreSettings(Map<String, dynamic> settings) async {
    // WebDAV 配置
    final webdav = settings['webdav'];
    if (webdav is Map) {
      final url = (webdav['url'] as String? ?? '').trim();
      if (url.isNotEmpty) {
        await saveWebDavConfig(
          url: url,
          username: webdav['username'] as String? ?? '',
          password: webdav['password'] as String? ?? '',
          directory: webdav['directory'] as String? ?? defaultWebDavDir,
        );
      }
    }

    // 各类开关（用类型安全读取，缺失则跳过）。
    if (settings['updateAutoCheck'] is bool) {
      await setUpdateAutoCheck(settings['updateAutoCheck'] as bool);
    }
    if (settings['updateIgnoredVersion'] is String) {
      await setUpdateIgnoredVersion(settings['updateIgnoredVersion'] as String);
    }
    if (settings['updatePermanentIgnored'] is bool) {
      await setUpdatePermanentIgnored(settings['updatePermanentIgnored'] as bool);
    }
    if (settings['updateSource'] is String) {
      await setUpdateSource(settings['updateSource'] as String);
    }
    if (settings['dataSyncAutoCheck'] is bool) {
      await setDataSyncAutoCheck(settings['dataSyncAutoCheck'] as bool);
    }
    if (settings['uiMode'] is String) {
      await setUiMode(settings['uiMode'] as String);
    }
    if (settings['showNavLabels'] is bool) {
      await setShowNavLabels(settings['showNavLabels'] as bool);
    }
    if (settings['uploadOnExit'] is bool) {
      await setUploadOnExit(settings['uploadOnExit'] as bool);
    }
    if (settings['forceSync'] is bool) {
      await setForceSync(settings['forceSync'] as bool);
    }
    if (settings['shortcutUseAvatar'] is bool) {
      await setShortcutUseAvatar(settings['shortcutUseAvatar'] as bool);
    }
    if (settings['shortcutUseName'] is bool) {
      await setShortcutUseName(settings['shortcutUseName'] as bool);
    }
    if (settings['shortcutCustomName'] is String) {
      await setShortcutCustomName(settings['shortcutCustomName'] as String);
    }
    if (settings['shortcutIconPath'] is String) {
      await setShortcutIconPath(settings['shortcutIconPath'] as String);
    }
    if (settings['useCustomAppDisplay'] is bool) {
      await setUseCustomAppDisplay(settings['useCustomAppDisplay'] as bool);
    }
  }

  /// 把快照 images 字段中的 base64 图片写回本地文件。
  ///
  /// 返回「原路径 → 新路径」映射。文件名带序号，避免重名覆盖。
  Future<Map<String, String>> _restoreImages(
    Map<String, dynamic> snapshot,
  ) async {
    final images = snapshot['images'];
    if (images is! Map) return const {};

    final result = <String, String>{};
    var index = 0;
    for (final entry in images.entries) {
      final base64 = entry.value;
      if (base64 is! String || base64.isEmpty) continue;
      index++;
      final ext = _inferImageExt(entry.key as String);
      final newPath = await ImageCompressor.saveBase64ToFile(
        base64,
        fileName: 'img_${DateTime.now().millisecondsSinceEpoch}_$index$ext',
      );
      if (newPath != null) {
        result[entry.key as String] = newPath;
      }
    }
    return result;
  }

  /// 根据原路径推断图片扩展名（默认 .jpg）。
  static String _inferImageExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    return '.jpg';
  }
}
