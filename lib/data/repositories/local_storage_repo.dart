import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
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

  Future<void> saveWebDavConfig({
    required String url,
    required String username,
    required String password,
  }) async {
    await _box.put(keyWebDavUrl, url);
    await _box.put(keyWebDavUser, username);
    await _box.put(keyWebDavPwd, password);
  }

  /// 是否已绑定 WebDAV（配置过有效地址即视为已绑定）。
  bool hasWebDavConfig() => getWebDavUrl().trim().isNotEmpty;

  (String, String, String) getWebDavConfig() {
    return (
      _box.get(keyWebDavUrl) as String? ?? '',
      _box.get(keyWebDavUser) as String? ?? '',
      _box.get(keyWebDavPwd) as String? ?? '',
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

  // ===== 全量快照 (供二维码/WebDAV 同步) =====
  Map<String, dynamic> buildSnapshot() {
    return {
      'family': getFamilyProfile()?.toJson(),
      'tasks': getTasks().map((t) => t.toJson()).toList(),
      'rewards': getRewards().map((r) => r.toJson()).toList(),
      'checkIns': getCheckIns().map((c) => c.toJson()).toList(),
      'exchanges': getExchanges().map((e) => e.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 从快照 Map 恢复全量数据。
  Future<void> restoreSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['family'] != null) {
      await saveFamilyProfile(
        FamilyProfile.fromJson(Map<String, dynamic>.from(snapshot['family'])),
      );
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
      await saveCheckIns(
        (snapshot['checkIns'] as List)
            .map((e) => CheckInRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    if (snapshot['exchanges'] != null) {
      await saveExchanges(
        (snapshot['exchanges'] as List)
            .map((e) => RewardExchange.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
  }
}
