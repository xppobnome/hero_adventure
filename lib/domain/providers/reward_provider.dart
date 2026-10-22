import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/reward_item.dart';
import '../../data/repositories/local_storage_repo.dart';
import 'family_provider.dart';

final rewardProvider = StateNotifierProvider<RewardNotifier, List<RewardItem>>((ref) {
  final storage = ref.watch(storageProvider);
  return RewardNotifier(storage)..loadRewards();
});

class RewardNotifier extends StateNotifier<List<RewardItem>> {
  final LocalStorageRepo _storage;

  RewardNotifier(this._storage) : super([]);

  // 从本地数据库加载，若为空则写入默认预设数据
  void loadRewards() {
    state = _storage.getRewards();

    if (state.isEmpty) {
      state = [
        RewardItem(id: 'r1', title: '看动画片 30 分钟', costCoins: 100, iconName: 'tv_icon'),
        RewardItem(id: 'r2', title: '游乐园门票一张', costCoins: 1000, iconName: 'park_icon'),
      ];
      _storage.saveRewards(state);
    }
  }

  // 新增奖励项
  void addReward(RewardItem reward) {
    state = [...state, reward];
    _storage.saveRewards(state);
  }

  // 更新奖励项
  void updateReward(RewardItem updatedReward) {
    state = state.map((reward) {
      if (reward.id == updatedReward.id) {
        return updatedReward;
      }
      return reward;
    }).toList();
    _storage.saveRewards(state);
  }

  // 删除奖励项
  void removeReward(String id) {
    state = state.where((reward) => reward.id != id).toList();
    _storage.saveRewards(state);
  }
}