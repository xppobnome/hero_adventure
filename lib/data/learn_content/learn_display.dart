/// 学习卡片展示 / 朗读分段的派生数据助手。
///
/// 统一处理三类需求：
/// - 中文「词语」解析 (识字 subText 的 '·' 后组词 / 拼音 subText 空格后例字)；
/// - 中文词拼音自动生成 (pinyin 包，带声调符)；
/// - 英文单词音标 (englishIpa 离线生成) 与中文释义拼音。
library;

import 'package:pinyin/pinyin.dart';

import 'english_ipa.dart';
import 'learn_item.dart';
import 'pinyin_data.dart';

class LearnDisplay {
  LearnDisplay._();

  /// 需要「额外朗读 + 在上方标注拼音」的中文词/字：
  /// - 识字：subText 中 '·' 后的组词 (如 '大山')；
  /// - 拼音：subText 中空格后的例字 (如 '波'，其呼读音已作为主朗读文本)；
  /// - 英文：中文释义本身 (作为「词语拼音」载体)。
  /// 没有则返回 null。
  static String? secondaryWord(LearnItem item) {
    switch (item.subject) {
      case LearnSubjects.hanzi:
        final idx = item.subText.indexOf('·');
        if (idx < 0) return null;
        final w = item.subText.substring(idx + 1).trim();
        return w.isEmpty ? null : w;
      case LearnSubjects.pinyin:
        final idx = item.subText.lastIndexOf(' ');
        if (idx < 0) return null;
        final w = item.subText.substring(idx + 1).trim();
        return w.isEmpty ? null : w;
      case LearnSubjects.english:
        return item.subText.isNotEmpty ? item.subText : null;
      default:
        return null;
    }
  }

  /// 中文词的带声调拼音 (如 "dà shān" / "píng guǒ")；非中文或无则返回空串。
  static String wordPinyin(LearnItem item) {
    final w = secondaryWord(item);
    if (w == null || !_hasChinese(w)) return '';
    try {
      return PinyinHelper.getPinyin(w, format: PinyinFormat.WITH_TONE_MARK);
    } catch (_) {
      return '';
    }
  }

  /// 英文单词音标 (IPA)；非英文或缺失返回 null。
  static String? ipaOf(LearnItem item) {
    if (item.subject != LearnSubjects.english) return null;
    final v = englishIpa[item.displayText];
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 朗读分段：按学科顺序返回 [(文本, 学科)]。
  /// - 识字：单字 → 组词 (均用中文模型)；
  /// - 拼音：声母 / 韵母 / 整体认读统一用中文模型朗读汉字呼读音
  ///   (speakText 已是对应汉字，如 f→「佛」、a→「啊」；声母纯辅音方案见 kShengmuPureConsonant)；
  /// - 英文：单词 (英文模型) → 中文释义 (中文模型)。
  static List<(String, String)> speakSegments(LearnItem item) {
    switch (item.subject) {
      case LearnSubjects.hanzi:
        final segs = <(String, String)>[(item.speakText, LearnSubjects.hanzi)];
        final w = secondaryWord(item);
        if (w != null) segs.add((w, LearnSubjects.hanzi));
        return segs;
      case LearnSubjects.pinyin:
        // 声母默认汉字呼读音 (中文模型，f→「佛」、b→「波」)；
        // kShengmuPureConsonant=true 时改回纯辅音 (英文模型音素合成，f→/f/)。
        if (kShengmuPureConsonant && item.category == 'shengmu') {
          final ph = pinyinInitialPhoneme[item.displayText];
          if (ph != null && ph.isNotEmpty) {
            return [(ph, LearnSubjects.phoneme)];
          }
        }
        // 声母(文字模式) / 韵母 / 整体认读：中文模型朗读汉字呼读音 (speakText 已是对应汉字)。
        return [(item.speakText, LearnSubjects.hanzi)];
      case LearnSubjects.english:
        return [
          (item.speakText, LearnSubjects.english),
          if (item.subText.isNotEmpty) (item.subText, LearnSubjects.hanzi),
        ];
      default:
        return [(item.speakText, item.subject)];
    }
  }

  /// 是否包含汉字 (CJK 统一表意文字)。
  static bool _hasChinese(String s) =>
      s.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);
}
