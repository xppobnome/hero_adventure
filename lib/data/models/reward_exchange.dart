/// 奖励兑换申请流水模型。
///
/// 儿童在商城中用能量币兑换现实奖励，产生一条申请记录，
/// 家长审核通过后发放，状态由 [requested] 变为 [approved]。
class RewardExchange {
  final String id;
  final String childId; // 申请儿童
  final String rewardId; // 关联商城奖励项
  final String rewardTitle; // 冗余奖励名称，便于展示
  final int costCoins; // 快照消耗币数
  final String status; // 'requested' (申请中) | 'approved' (已发放) | 'rejected' (已驳回)
  final DateTime createdAt;

  RewardExchange({
    required this.id,
    required this.childId,
    required this.rewardId,
    required this.rewardTitle,
    required this.costCoins,
    required this.status,
    required this.createdAt,
  });

  factory RewardExchange.fromJson(Map<String, dynamic> json) {
    return RewardExchange(
      id: json['id'] as String,
      childId: json['childId'] as String,
      rewardId: json['rewardId'] as String,
      rewardTitle: json['rewardTitle'] as String? ?? '',
      costCoins: json['costCoins'] as int? ?? 0,
      status: json['status'] as String? ?? 'requested',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'costCoins': costCoins,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  RewardExchange copyWith({String? status}) {
    return RewardExchange(
      id: id,
      childId: childId,
      rewardId: rewardId,
      rewardTitle: rewardTitle,
      costCoins: costCoins,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
