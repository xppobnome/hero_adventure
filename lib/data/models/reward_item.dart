class RewardItem {
  final String id;
  final String title;
  final int costCoins;
  final String iconName;
  final bool requireApproval; // 是否需要家长审核（false = 兑换即发放）

  RewardItem({
    required this.id,
    required this.title,
    required this.costCoins,
    required this.iconName,
    this.requireApproval = true,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    return RewardItem(
      id: json['id'] as String,
      title: json['title'] as String,
      costCoins: json['costCoins'] as int,
      iconName: json['iconName'] as String,
      requireApproval: json['requireApproval'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'costCoins': costCoins,
      'iconName': iconName,
      'requireApproval': requireApproval,
    };
  }
}