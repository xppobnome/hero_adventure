/// 打卡记录流水模型。
///
/// 一次「消灭怪兽」打卡对应一条记录：
/// - 普通任务：完成后状态直接为 [completed]
/// - 需要拍照凭证的任务：先进入 [pending]，待家长审核后转为 [completed]
class CheckInRecord {
  final String id;
  final String childId; // 关联儿童
  final String taskId; // 关联任务
  final String status; // 'pending' (待审核) | 'completed' (已完成) | 'rejected' (已驳回)
  final String date; // 日期索引 YYYY-MM-DD
  final String? proofImage; // 本地图片路径 (可为空)
  final int rewardCoins; // 快照奖励币 (审批通过时下发)
  final int rewardExp; // 快照奖励经验
  final DateTime createdAt; // 创建时间戳

  CheckInRecord({
    required this.id,
    required this.childId,
    required this.taskId,
    required this.status,
    required this.date,
    this.proofImage,
    this.rewardCoins = 0,
    this.rewardExp = 0,
    required this.createdAt,
  });

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      id: json['id'] as String,
      childId: json['childId'] as String,
      taskId: json['taskId'] as String,
      status: json['status'] as String? ?? 'pending',
      date: json['date'] as String? ?? '',
      proofImage: json['proofImage'] as String?,
      rewardCoins: json['rewardCoins'] as int? ?? 0,
      rewardExp: json['rewardExp'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'taskId': taskId,
      'status': status,
      'date': date,
      'proofImage': proofImage,
      'rewardCoins': rewardCoins,
      'rewardExp': rewardExp,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CheckInRecord copyWith({
    String? status,
    String? proofImage,
    int? rewardCoins,
    int? rewardExp,
  }) {
    return CheckInRecord(
      id: id,
      childId: childId,
      taskId: taskId,
      status: status ?? this.status,
      date: date,
      proofImage: proofImage ?? this.proofImage,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      rewardExp: rewardExp ?? this.rewardExp,
      createdAt: createdAt,
    );
  }
}
