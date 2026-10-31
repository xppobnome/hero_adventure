import '../data/learn_content/learn_item.dart';

/// 跟读判分纯函数 (与 UI 解耦，可单测)。
///
/// 判分规则 (与架构 §7 共享知识一致)：
/// - 拼音/识字：去声调 → ü 系列转 v → lowercase → 去空格。
/// - 英语：lowercase → trim → 折叠连续空格为单个。
///
/// 关键难点 (zh_CN 语音识别的「汉字 vs 拼音」歧义)：
/// - 跟读拼音时，儿童读出的是「呼读音」 (如 b 读「波」)，而 zh_CN 识别
///   可能返回拼音字母 'bo'，也可能返回同音汉字「波」「玻」等。
/// - 因此 [isMatch] 在比对前，会把识别结果中的常见同音汉字转换为拼音，
///   再与 [LearnItem.matchTargets] (同时含字母与汉字) 归一化比对，
///   大幅提升「我读一遍」的判分命中率。
class LearnJudge {
  LearnJudge._();

  /// 拼音声调/ü 到基础字母的映射 (Unicode 预组合字符)。
  ///
  /// 覆盖拼音常见声调：a/e/i/o/u 的四声，以及 ü 系列 (含四声) 统一映射为 v。
  static const Map<int, String> _toneMap = {
    // a
    0x0101: 'a', 0x00E1: 'a', 0x01CE: 'a', 0x00E0: 'a',
    // e
    0x0113: 'e', 0x00E9: 'e', 0x011B: 'e', 0x00E8: 'e',
    // i
    0x012B: 'i', 0x00ED: 'i', 0x01D0: 'i', 0x00EC: 'i',
    // o
    0x014D: 'o', 0x00F3: 'o', 0x01D2: 'o', 0x00F2: 'o',
    // u
    0x016B: 'u', 0x00FA: 'u', 0x01D4: 'u', 0x00F9: 'u',
    // ü (含四声) → v
    0x00FC: 'v', 0x01D6: 'v', 0x01D8: 'v', 0x01DA: 'v', 0x01DC: 'v',
  };

  /// 是否为 Unicode 组合附加符号 (Mn 类，覆盖 U+0300–U+036F)。
  ///
  /// 用于处理「分解形式」(如 'a' + U+0304 表示 ā) 的输入，直接丢弃组合声调符。
  static bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

  /// 拼音/识字归一化：去声调 + ü→v + lowercase + 去空格。
  static String normalizePinyin(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final mapped = _toneMap[rune];
      if (mapped != null) {
        buffer.write(mapped);
      } else if (_isCombiningMark(rune)) {
        // 丢弃组合声调符
        continue;
      } else {
        final ch = String.fromCharCode(rune);
        // 跳过空格/空白，其余原样保留
        if (ch.trim().isNotEmpty) buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// 英语归一化：lowercase → trim → 折叠连续空格为单个。
  static String normalizeEnglish(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 常见同音汉字 → 拼音 (去声调、ü→v) 映射。
  ///
  /// 覆盖拼音呼读音、识字高频字、以及 zh_CN 识别易混同音字。
  /// 用于把识别返回的汉字转换为可比的拼音，再与 matchTargets 比对。
  static const Map<String, String> _hanziToPinyin = {
    // 声母呼读音对应汉字
    '波': 'bo', '玻': 'bo', '菠': 'bo', '播': 'bo',
    '坡': 'po', '泼': 'po', '颇': 'po',
    '摸': 'mo', '磨': 'mo', '魔': 'mo', '膜': 'mo',
    '佛': 'fo',
    '得': 'de', '德': 'de',
    '特': 'te',
    '讷': 'ne', '呢': 'ne',
    '勒': 'le', '了': 'le', '乐': 'le',
    '哥': 'ge', '歌': 'ge', '个': 'ge', '各': 'ge',
    '科': 'ke', '可': 'ke', '棵': 'ke', '颗': 'ke',
    '喝': 'he', '和': 'he', '河': 'he', '合': 'he', '禾': 'he',
    '鸡': 'ji', '机': 'ji', '基': 'ji', '几': 'ji',
    '七': 'qi', '期': 'qi', '气': 'qi', '其': 'qi', '起': 'qi',
    '西': 'xi', '洗': 'xi', '习': 'xi', '细': 'xi', '喜': 'xi',
    '知': 'zhi', '只': 'zhi', '支': 'zhi', '纸': 'zhi', '直': 'zhi',
    '吃': 'chi', '迟': 'chi', '尺': 'chi',
    '师': 'shi', '是': 'shi', '十': 'shi', '时': 'shi', '石': 'shi', '市': 'shi',
    '日': 'ri',
    '资': 'zi', '字': 'zi', '子': 'zi', '自': 'zi',
    '雌': 'ci', '词': 'ci', '此': 'ci', '次': 'ci',
    '思': 'si', '四': 'si', '死': 'si', '丝': 'si', '司': 'si',
    '衣': 'yi', '一': 'yi', '以': 'yi', '已': 'yi', '义': 'yi', '意': 'yi', '椅': 'yi',
    '乌': 'wu', '五': 'wu', '无': 'wu', '屋': 'wu', '舞': 'wu', '物': 'wu', '午': 'wu',
    // 单字母韵母呼读音
    '啊': 'a', '阿': 'a',
    '喔': 'o', '哦': 'o',
    '鹅': 'e', '饿': 'e', '恶': 'e', '额': 'e',
    '迂': 'yu', '鱼': 'yu', '雨': 'yu', '与': 'yu', '语': 'yu', '玉': 'yu', '于': 'yu',
    // 复韵母/鼻韵母呼读音
    '挨': 'ai', '爱': 'ai', '矮': 'ai',
    '诶': 'ei',
    '威': 'wei', '为': 'wei', '位': 'wei', '未': 'wei', '围': 'wei', '微': 'wei',
    '熬': 'ao', '袄': 'ao', '奥': 'ao',
    '欧': 'ou', '偶': 'ou',
    '优': 'you', '有': 'you', '又': 'you', '友': 'you', '右': 'you', '游': 'you',
    '耶': 'ye', '也': 'ye', '业': 'ye', '夜': 'ye', '爷': 'ye', '页': 'ye',
    '约': 'yue', '月': 'yue', '越': 'yue', '跃': 'yue', '阅': 'yue',
    '耳': 'er', '二': 'er', '儿': 'er', '而': 'er',
    '安': 'an', '按': 'an', '暗': 'an', '岸': 'an',
    '恩': 'en',
    '因': 'yin', '音': 'yin', '银': 'yin', '引': 'yin', '饮': 'yin',
    '温': 'wen', '文': 'wen', '问': 'wen', '闻': 'wen', '稳': 'wen',
    '晕': 'yun', '云': 'yun', '运': 'yun', '允': 'yun', '韵': 'yun',
    '昂': 'ang',
    '鞥': 'eng',
    '英': 'ying', '应': 'ying', '影': 'ying', '硬': 'ying', '迎': 'ying',
    '嗡': 'ong',
    '圆': 'yuan', '元': 'yuan', '远': 'yuan', '院': 'yuan', '原': 'yuan', '愿': 'yuan',
  };

  /// 把识别文本中出现的同音汉字替换为拼音，便于与 matchTargets 比对。
  ///
  /// 仅替换 [LearnJudge] 已知的呼读音/高频同音字；未被识别的汉字原样保留，
  /// 不影响英语判分 (英语走 [normalizeEnglish]，不经过本函数)。
  static String _hanziToPinyinSafe(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final pinyin = _hanziToPinyin[ch];
      buffer.write(pinyin ?? ch);
    }
    return buffer.toString();
  }

  /// 统一判分入口：对 [item] 的 matchTargets 逐个归一化比较。
  ///
  /// 返回 true 表示识别结果与任一目标近似匹配。
  static bool isMatch({required String recognized, required LearnItem item}) {
    final isEnglish = item.subject == LearnSubjects.english;
    if (isEnglish) {
      final r = normalizeEnglish(recognized);
      if (r.isEmpty) return false;
      for (final target in item.matchTargets) {
        if (normalizeEnglish(target) == r) return true;
      }
      return false;
    }

    // 识字：speakText/displayText 本身即汉字，识别返回也多为汉字。
    // 除拼音归一化比对外，额外直接比较「识别文本是否含目标汉字」，
    // 覆盖 zh_CN 识别返回汉字 (而非拼音) 的场景。
    final isHanzi = item.subject == LearnSubjects.hanzi;

    // 拼音/识字：先把识别文本中的同音汉字转为拼音，再归一化。
    final r = normalizePinyin(_hanziToPinyinSafe(recognized));
    if (r.isEmpty) return false;

    for (final target in item.matchTargets) {
      final norm = normalizePinyin(_hanziToPinyinSafe(target));
      if (norm.isNotEmpty && norm == r) return true;
    }

    // 识字兜底：识别文本含目标汉字即视为读对 (处理「人」识别为「人」等
    // 未收录进同音映射的高频字)。
    if (isHanzi && item.displayText.isNotEmpty && recognized.contains(item.displayText)) {
      return true;
    }

    return false;
  }
}
