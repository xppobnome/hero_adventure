import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/force_sync.dart';
import '../../data/models/child_profile.dart';
import '../../data/models/family_profile.dart';
import '../../data/repositories/local_storage_repo.dart';
import '../hero_system.dart' show expForLevel, maxLevel;

// ==========================================
// 1. 所有的 Providers 都放在全局最顶层 (类的外部)
// ==========================================

// 提供 LocalStorageRepo 的全局单例
final storageProvider = Provider<LocalStorageRepo>((ref) {
  throw UnimplementedError('StorageProvider must be initialized before use');
});

// 管理 FamilyProfile 状态
final familyProfileProvider = StateNotifierProvider<FamilyProfileNotifier, FamilyProfile?>((ref) {
  final storage = ref.watch(storageProvider);
  return FamilyProfileNotifier(storage);
});

// ====== 新增：设备终端绑定状态 Provider ======
// 记录当前设备绑定状态，依赖于 LocalStorageRepo 的 getDeviceRole()
// 返回: 'unbound' (未绑定), 'parent' (家长设备), 或者具体的 childId
final deviceRoleProvider = StateProvider<String>((ref) {
  final storage = ref.watch(storageProvider);
  return storage.getDeviceRole();
});

// ====== 新增：家长菜单栏文字标签是否展示 ======
// 默认从本地读取；切换时同步写入 storage 并更新此状态，供菜单栏即时响应。
final showNavLabelsProvider = StateProvider<bool>((ref) {
  final storage = ref.watch(storageProvider);
  return storage.getShowNavLabels();
});

// ==========================================
// 2. 状态管理类 (内部只写业务逻辑，不能声明 Provider)
// ==========================================

class FamilyProfileNotifier extends StateNotifier<FamilyProfile?> {
  final LocalStorageRepo _storage;

  FamilyProfileNotifier(this._storage) : super(_storage.getFamilyProfile());

  Future<void> createFamily(FamilyProfile profile) async {
    await _storage.saveFamilyProfile(profile);
    state = profile;
  }

  Future<void> updateChildExp(String childId, int addedExp, int addedCoins) async {
    if (state == null) return;

    final updatedChildren = state!.children.map((child) {
      if (child.id == childId) {
        return child.copyWith(
          exp: child.exp + addedExp,
          coins: child.coins + addedCoins,
        );
      }
      return child;
    }).toList();

    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );

    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 发放奖励经验与能量币 (审核通过后调用)。
  Future<void> grantReward(String childId, int addedExp, int addedCoins) async {
    await updateChildExp(childId, addedExp, addedCoins);
    // 审核通过发放奖励是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }

  /// 扣除能量币 (兑换发放时调用)，返回是否成功。
  Future<bool> spendCoins(String childId, int costCoins) async {
    if (state == null) return false;
    final child = state!.children.firstWhere(
      (c) => c.id == childId,
      orElse: () => throw StateError('child not found'),
    );
    if (child.coins < costCoins) return false;

    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(coins: c.coins - costCoins);
      }
      return c;
    }).toList();

    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
    // 兑换扣币是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
    return true;
  }

  /// 退回能量币 (兑换被驳回时调用)。
  Future<void> refundCoins(String childId, int refundCoins) async {
    if (state == null) return;
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(coins: c.coins + refundCoins);
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
    // 退回能量币是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }

  /// 新增儿童档案 (一户多宝)。
  Future<void> addChild(ChildProfile child) async {
    if (state == null) return;
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: [...state!.children, child],
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 选择出战英雄 (儿童端英雄图鉴点选后调用)。
  Future<void> selectHero(String childId, String heroId) async {
    if (state == null) return;
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(currentHeroId: heroId);
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 更新儿童年龄 (家长端 / 首次配置调用)。
  Future<void> updateChildAge(String childId, int age) async {
    if (state == null) return;
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(age: age);
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 更新儿童档案 (姓名 / 头像 / 年龄，传 null 表示不修改)。
  Future<void> updateChildProfile(
    String childId, {
    String? name,
    String? avatarImage,
    int? age,
  }) async {
    if (state == null) return;
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(
          name: name ?? c.name,
          avatarImage: avatarImage ?? c.avatarImage,
          age: age ?? c.age,
        );
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  // 切换主题
  void updateTheme(String newTheme) async {
    if (state == null) return;

    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: newTheme,
      pinCode: state!.pinCode,
      children: state!.children,
    );

    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  // 修改防卫密码
  void updatePin(String newPin) async {
    if (state == null) return;

    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: newPin,
      children: state!.children,
    );

    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 【调试】直接设置某儿童的等级 (折算经验值) 与能量币数量。
  Future<void> debugSetChildExpAndCoins(
    String childId, {
    required int exp,
    required int coins,
  }) async {
    if (state == null) return;
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(exp: exp, coins: coins);
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 【调试】解锁全部英雄：把儿童等级设为满级，使其达到所有英雄解锁等级。
  Future<void> debugUnlockAllHeroes(String childId) async {
    if (state == null) return;
    // 满级经验值 = 达到 maxLevel 所需累计经验。
    int maxExp = 0;
    for (int l = 2; l <= maxLevel; l++) {
      maxExp += expForLevel(l);
    }
    final updatedChildren = state!.children.map((c) {
      if (c.id == childId) {
        return c.copyWith(exp: maxExp);
      }
      return c;
    }).toList();
    final updatedProfile = FamilyProfile(
      familyId: state!.familyId,
      currentTheme: state!.currentTheme,
      pinCode: state!.pinCode,
      children: updatedChildren,
    );
    await _storage.saveFamilyProfile(updatedProfile);
    state = updatedProfile;
  }

  /// 【调试】一键复原：从快照恢复整个家庭档案，并清空快照。
  Future<void> debugRestoreFromSnapshot() async {
    final snapshot = _storage.getDebugSnapshot();
    if (snapshot == null) return;
    await _storage.saveFamilyProfile(snapshot);
    state = snapshot;
    await _storage.clearDebugSnapshot();
  }
}