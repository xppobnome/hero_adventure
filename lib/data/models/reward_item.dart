class RewardItem {
  final String id;
  final String title;
  final int costCoins;
  final String iconName;

  RewardItem({
    required this.id,
    required this.title,
    required this.costCoins,
    required this.iconName,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    return RewardItem(
      id: json['id'] as String,
      title: json['title'] as String,
      costCoins: json['costCoins'] as int,
      iconName: json['iconName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'costCoins': costCoins,
      'iconName': iconName,
    };
  }
}