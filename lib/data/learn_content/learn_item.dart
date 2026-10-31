/// 学习模块统一数据模型与学科约定。
///
/// 三个跟读模块 (学拼音 / 识字 / 学英语) 共用 [LearnItem] 作为字库条目，
/// 仅在 subject / 展示文本 / 朗读文本 / 判分目标上存在差异。
library;

import 'english_data.dart';
import 'hanzi_data.dart';
import 'pinyin_data.dart';

/// 学科取值常量 (与 Task.type 的字符串风格一致)。
class LearnSubjects {
  LearnSubjects._();

  static const String pinyin = 'pinyin';
  static const String hanzi = 'hanzi';
  static const String english = 'english';
}

/// 统一的跟读条目模型，三个模块共用。
class LearnItem {
  /// 学科：LearnSubjects.pinyin / hanzi / english。
  final String subject;

  /// 大字号主展示：'b' / '人' / 'apple'。
  final String displayText;

  /// 辅助说明：呼读音 'bō' / 拼音+组词 'rén · 大人' / 释义 '苹果'。
  final String subText;

  /// TTS 朗读文本 (声母用呼读音，避免被 TTS 读成英文)。
  final String speakText;

  /// 判分允许的等价目标 (归一化后比较)，至少 1 项。
  final List<String> matchTargets;

  /// 分类：拼音 shengmu/yunmu/zhengti；识字/英语 'all' (预留分级)。
  final String category;

  const LearnItem({
    required this.subject,
    required this.displayText,
    this.subText = '',
    required this.speakText,
    required this.matchTargets,
    this.category = 'all',
  });
}

/// 学科 → TTS 语言。
String ttsLanguageOf(String subject) =>
    subject == LearnSubjects.english ? 'en-US' : 'zh-CN';

/// 学科 → 语音识别 localeId。
String sttLocaleOf(String subject) =>
    subject == LearnSubjects.english ? 'en_US' : 'zh_CN';

/// 学科中文名 (家长端 / 儿童端展示用)。
String learnSubjectLabel(String subject) => switch (subject) {
      LearnSubjects.pinyin => '学拼音',
      LearnSubjects.hanzi => '识字',
      LearnSubjects.english => '学英语',
      _ => '学习',
    };

/// 依据学科返回对应字库 (供抽题器与判分复用)。
List<LearnItem> learnTableFor(String subject) => switch (subject) {
      LearnSubjects.pinyin => pinyinTable,
      LearnSubjects.hanzi => hanziTable,
      LearnSubjects.english => englishWordTable,
      _ => const [],
    };

/// 按学科 + 范围过滤字库。
///
/// 拼音本轮已移除声母/韵母/整体认读分类，统一按全部拼音顺序/随机抽取，
/// 因此 [scope] 不再参与拼音过滤 (无论传入何值都返回完整拼音表)。
/// 识字/英语同样返回全部字库。
List<LearnItem> filterLearnTable(String subject, String scope) {
  return learnTableFor(subject);
}
