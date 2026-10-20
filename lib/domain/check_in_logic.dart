import '../data/models/check_in_record.dart';
import '../data/models/task.dart';

/// 打卡周期校验与关卡状态判定的统一业务逻辑。
///
/// 集中处理「某任务在某日期是否可以打卡 / 是否已完成 / 是否待审核」，
/// 供儿童端冒险地图与家长端进度看板复用，避免判定规则散落各处。
class CheckInLogic {
  CheckInLogic._();

  /// 一周的连续打卡记录 (针对 checkin_week 类型的任务) 所需天数。
  static const int checkinWeekDays = 7;

  /// 判定任务在指定日期 (YYYY-MM-DD) 是否「可打卡」。
  ///
  /// 规则：
  /// - `daily`      每天可打
  /// - `weekly`     每周内任意一天可打 (但当天打过后不可重复)
  /// - `once`       全程只可打一次
  /// - `custom_days`仅选中星期几可打
  /// - `checkin_week` 每天可打，累计满 7 天后视为完成
  static bool isAvailable({
    required Task task,
    required String childId,
    required String date,
    required List<CheckInRecord> records,
  }) {
    final completedToday = _hasStatus(task, childId, date, records, 'completed');
    final pendingToday = _hasStatus(task, childId, date, records, 'pending');

    // 当天已完成或待审核，不可再次打卡
    if (completedToday || pendingToday) return false;

    // 单次任务：全程完成过一次即不再可打
    if (task.type == 'once') {
      final everCompleted = records.any(
        (r) => r.childId == childId && r.taskId == task.id && r.status == 'completed',
      );
      if (everCompleted) return false;
      return true;
    }

    // 指定日期任务：非选中星期几不可打
    if (task.type == 'custom_days') {
      final weekday = _weekdayOf(date);
      if (weekday == null) return false;
      return task.selectedDays.contains(weekday);
    }

    // 打卡一周：累计满 7 天后整体完成，之后不再可打
    if (task.type == 'checkin_week') {
      final completedDays = _completedDistinctDates(task, childId, records);
      if (completedDays.length >= checkinWeekDays) return false;
      return true;
    }

    // daily / weekly 默认可打
    return true;
  }

  /// 判定任务在指定日期是否「已完成」。
  static bool isCompleted({
    required Task task,
    required String childId,
    required String date,
    required List<CheckInRecord> records,
  }) {
    // 打卡一周任务：累计满 7 天即整体完成
    if (task.type == 'checkin_week') {
      return _completedDistinctDates(task, childId, records).length >= checkinWeekDays;
    }
    return _hasStatus(task, childId, date, records, 'completed');
  }

  /// 判定任务在指定日期是否「待审核」。
  static bool isPending({
    required Task task,
    required String childId,
    required String date,
    required List<CheckInRecord> records,
  }) {
    return _hasStatus(task, childId, date, records, 'pending');
  }

  /// 打卡一周任务的已完成天数 (去重后的日期数)。
  static int completedDaysOfWeek({
    required Task task,
    required String childId,
    required List<CheckInRecord> records,
  }) {
    return _completedDistinctDates(task, childId, records).length;
  }

  /// 打卡一周任务的进度描述 (已完成 x / 7 天)。
  static String checkinWeekProgress({
    required Task task,
    required String childId,
    required List<CheckInRecord> records,
  }) {
    final days = completedDaysOfWeek(task: task, childId: childId, records: records);
    return '$days / $checkinWeekDays';
  }

  // ===== 内部辅助 =====

  static bool _hasStatus(
    Task task,
    String childId,
    String date,
    List<CheckInRecord> records,
    String status,
  ) {
    return records.any(
      (r) => r.childId == childId && r.taskId == task.id && r.date == date && r.status == status,
    );
  }

  /// 该儿童在该任务下已完成打卡的去重日期集合。
  static Set<String> _completedDistinctDates(
    Task task,
    String childId,
    List<CheckInRecord> records,
  ) {
    return records
        .where((r) =>
            r.childId == childId && r.taskId == task.id && r.status == 'completed')
        .map((r) => r.date)
        .toSet();
  }

  /// 从日期字符串解析星期几 (1=周一 ... 7=周日)，解析失败返回 null。
  static int? _weekdayOf(String date) {
    final d = DateTime.tryParse(date);
    return d?.weekday;
  }
}
