class ChildProfile {
  final String id;
  final String name;
  final int coins;
  final int exp;
  final String currentHeroId; // 当前出战英雄
  final int age; // 儿童年龄 (岁)
  final String avatarImage; // 头像本地路径 (空则用默认占位)

  ChildProfile({
    required this.id,
    required this.name,
    this.coins = 0,
    this.exp = 0,
    this.currentHeroId = 'ace',
    this.age = 6,
    this.avatarImage = '',
  });

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      coins: json['coins'] as int? ?? 0,
      exp: json['exp'] as int? ?? 0,
      currentHeroId: json['currentHeroId'] as String? ?? 'ace',
      age: json['age'] as int? ?? 6,
      avatarImage: json['avatarImage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coins': coins,
      'exp': exp,
      'currentHeroId': currentHeroId,
      'age': age,
      'avatarImage': avatarImage,
    };
  }

  ChildProfile copyWith({
    String? id,
    String? name,
    int? coins,
    int? exp,
    String? currentHeroId,
    int? age,
    String? avatarImage,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      exp: exp ?? this.exp,
      currentHeroId: currentHeroId ?? this.currentHeroId,
      age: age ?? this.age,
      avatarImage: avatarImage ?? this.avatarImage,
    );
  }
}