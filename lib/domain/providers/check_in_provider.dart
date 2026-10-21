import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/force_sync.dart';
import '../../data/models/check_in_record.dart';
import '../../data/repositories/local_storage_repo.dart';
import 'family_provider.dart';

/// 打卡记录全局状态。
final checkInProvider =
    StateNotifierProvider<CheckInNotifier, List<CheckInRecord>>((ref) {
  final storage = ref.watch(storageProvider);
  return CheckInNotifier(storage)..load();
});

class CheckInNotifier extends StateNotifier<List<CheckInRecord>> {
  final LocalStorageRepo _storage;

  CheckInNotifier(this._storage) : super([]);

  void load() {
    state = _storage.getCheckIns();
  }

  /// 新增一条打卡记录。
  /// [requirePhoto] 为 true 时进入 pending 待审核，否则直接 completed。
  Future<void> addCheckIn({
    required String childId,
    required String taskId,
    required bool requirePhoto,
    required int rewardCoins,
    required int rewardExp,
    String? proofImage,
  }) async {
    final record = CheckInRecord(
      id: const Uuid().v4(),
      childId: childId,
      taskId: taskId,
      status: requirePhoto ? 'pending' : 'completed',
      date: _today(),
      proofImage: proofImage,
      rewardCoins: rewardCoins,
      rewardExp: rewardExp,
      createdAt: DateTime.now(),
    );
    state = [record, ...state];
    await _storage.saveCheckIns(state);
    // 打卡是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }

  /// 家长审核：approve=true 通过 (completed)，否则驳回 (rejected)。
  Future<void> review(String recordId, bool approve) async {
    state = state.map((r) {
      if (r.id == recordId) {
        return r.copyWith(status: approve ? 'completed' : 'rejected');
      }
      return r;
    }).toList();
    await _storage.saveCheckIns(state);
    // 审核通过/驳回是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }

  /// 某儿童在指定日期的已完成打卡记录。
  List<CheckInRecord> completedByChildOn(String childId, String date) {
    return state
        .where((r) => r.childId == childId && r.date == date && r.status == 'completed')
        .toList();
  }

  /// 某儿童某任务在指定日期是否已打卡完成 (用于关卡状态判定)。
  bool hasCompleted(String childId, String taskId, String date) {
    return state.any((r) =>
        r.childId == childId &&
        r.taskId == taskId &&
        r.date == date &&
        r.status == 'completed');
  }

  String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

/// 某儿童的全部打卡记录 (派生)。
final childCheckInProvider = Provider.family<List<CheckInRecord>, String>(
  (ref, childId) {
    final all = ref.watch(checkInProvider);
    return all.where((r) => r.childId == childId).toList();
  },
);
