import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  Future<void> requestExchange({
    required String childId,
    required String rewardId,
    required String rewardTitle,
    required int costCoins,
  }) async {
    final exchange = RewardExchange(
      id: const Uuid().v4(),
      childId: childId,
      rewardId: rewardId,
      rewardTitle: rewardTitle,
      costCoins: costCoins,
      status: 'requested',
      createdAt: DateTime.now(),
    );
    state = [exchange, ...state];
    await _storage.saveExchanges(state);
  }

  /// 家长审批兑换：approve=true 发放，否则驳回。
  Future<void> review(String exchangeId, bool approve) async {
    state = state.map((e) {
      if (e.id == exchangeId) {
        return e.copyWith(status: approve ? 'approved' : 'rejected');
      }
      return e;
    }).toList();
    await _storage.saveExchanges(state);
  }
}
