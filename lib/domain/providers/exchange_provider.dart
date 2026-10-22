import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/force_sync.dart';
import '../../data/models/reward_exchange.dart';
import '../../data/repositories/local_storage_repo.dart';
import 'family_provider.dart';

/// 奖励兑换申请全局状态。
final exchangeProvider =
    StateNotifierProvider<ExchangeNotifier, List<RewardExchange>>((ref) {
  final storage = ref.watch(storageProvider);
  return ExchangeNotifier(storage)..load();
});

class ExchangeNotifier extends StateNotifier<List<RewardExchange>> {
  final LocalStorageRepo _storage;

  ExchangeNotifier(this._storage) : super([]);

  void load() {
    state = _storage.getExchanges();
  }

  /// 儿童发起兑换申请。
  ///
  /// [requireApproval] 为 false 时（免审核奖励），兑换直接完成，状态为
  /// 'completed'；否则进入 'requested' 待家长审核。
  /// 注意：能量币在「发起兑换」时即由调用方扣除；驳回时由审批方退回。
  Future<void> requestExchange({
    required String childId,
    required String rewardId,
    required String rewardTitle,
    required int costCoins,
    required bool requireApproval,
  }) async {
    final exchange = RewardExchange(
      id: const Uuid().v4(),
      childId: childId,
      rewardId: rewardId,
      rewardTitle: rewardTitle,
      costCoins: costCoins,
      status: requireApproval ? 'requested' : 'completed',
      requireApproval: requireApproval,
      createdAt: DateTime.now(),
    );
    state = [exchange, ...state];
    await _storage.saveExchanges(state);
    // 兑换申请是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }

  /// 家长审批兑换：approve=true 发放，否则驳回。
  /// 能量币已在兑换发起时扣除，故这里只更新状态；驳回时的退回由审批方负责。
  Future<void> review(String exchangeId, bool approve) async {
    state = state.map((e) {
      if (e.id == exchangeId) {
        return e.copyWith(status: approve ? 'approved' : 'rejected');
      }
      return e;
    }).toList();
    await _storage.saveExchanges(state);
    // 兑换审批是重要变更，若开启「变更时强制同步」则自动上传云端。
    await ForceSyncHelper.maybeSync(_storage);
  }
}
