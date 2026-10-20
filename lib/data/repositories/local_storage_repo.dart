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
  static const String keyWebDavUrl = 'webdav_url'; // WebDAV 地址
  static const String keyWebDavUser = 'webdav_user'; // WebDAV 账号
  static const String keyWebDavPwd = 'webdav_pwd'; // WebDAV 密码
  static const String keyWebDavDir =
      'webdav_dir'; // WebDAV 存储目录（默认 /HeroAdventure）
  static const String keyDataSyncAutoCheck =
      'datasync_auto_check'; // 启动时检查云端数据版本开关
  static const String keyLastSyncedUploadAt =
      'last_synced_upload_at'; // 本机最近一次同步的云端时间戳

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
      'timestamp': DateTime.now().toIso8601String(),
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
