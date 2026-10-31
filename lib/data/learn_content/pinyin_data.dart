/// 拼音全表 (63 项)。
///
/// 来源：部编版小学语文一年级汉语拼音教学大纲。
/// 结构：声母 23 + 韵母 24 + 整体认读音节 16 = 63。
///
/// 约定 (见架构 §7 共享知识)：
/// - 所有拼音项的 [speakText] 一律使用**汉字呼读音** (声母 b→「波」、韵母 a→「啊」、
///   整体认读 zhi→「知」等)，避免 TTS 把 'b'/'a' 读成英文 'bee'/'ay'。
/// - [matchTargets] 同时容纳「字母拼音 (去声调)」与「呼读音对应常见汉字」，
///   因为 zh_CN 语音识别可能返回拼音字母，也可能返回同音汉字 (如 b → 「波」)。
///   判分前由 [LearnJudge] 统一做汉字→拼音转换后比对，提高跟读判分的命中率。
/// - 含 ü 的韵母在 [matchTargets] 额外容纳 'u' 变体，提升识别容错。
library;

import 'learn_item.dart';

const List<LearnItem> pinyinTable = [
  // ===== 声母 (23) — 用呼读音对应汉字朗读 =====
  LearnItem(subject: 'pinyin', displayText: 'b', subText: 'bō 波', speakText: '波', matchTargets: ['b', 'bo', '波'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'p', subText: 'pō 坡', speakText: '坡', matchTargets: ['p', 'po', '坡'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'm', subText: 'mō 摸', speakText: '摸', matchTargets: ['m', 'mo', '摸'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'f', subText: 'fō 佛', speakText: '佛', matchTargets: ['f', 'fo', '佛'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'd', subText: 'dē 得', speakText: '得', matchTargets: ['d', 'de', '得'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 't', subText: 'tē 特', speakText: '特', matchTargets: ['t', 'te', '特'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'n', subText: 'ne 呢', speakText: '呢', matchTargets: ['n', 'ne', '呢'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'l', subText: 'lē 勒', speakText: '勒', matchTargets: ['l', 'le', '勒'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'g', subText: 'gē 哥', speakText: '哥', matchTargets: ['g', 'ge', '哥'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'k', subText: 'kē 科', speakText: '科', matchTargets: ['k', 'ke', '科'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'h', subText: 'hē 喝', speakText: '喝', matchTargets: ['h', 'he', '喝'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'j', subText: 'jī 鸡', speakText: '鸡', matchTargets: ['j', 'ji', '鸡'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'q', subText: 'qī 七', speakText: '七', matchTargets: ['q', 'qi', '七'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'x', subText: 'xī 西', speakText: '西', matchTargets: ['x', 'xi', '西'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'zh', subText: 'zhī 知', speakText: '知', matchTargets: ['zh', 'zhi', '知'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'ch', subText: 'chī 吃', speakText: '吃', matchTargets: ['ch', 'chi', '吃'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'sh', subText: 'shī 师', speakText: '师', matchTargets: ['sh', 'shi', '师'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'r', subText: 'rī 日', speakText: '日', matchTargets: ['r', 'ri', '日'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'z', subText: 'zī 资', speakText: '资', matchTargets: ['z', 'zi', '资'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'c', subText: 'cī 雌', speakText: '雌', matchTargets: ['c', 'ci', '雌'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 's', subText: 'sī 思', speakText: '思', matchTargets: ['s', 'si', '思'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'y', subText: 'yī 衣', speakText: '衣', matchTargets: ['y', 'yi', '衣'], category: 'shengmu'),
  LearnItem(subject: 'pinyin', displayText: 'w', subText: 'wū 乌', speakText: '乌', matchTargets: ['w', 'wu', '乌'], category: 'shengmu'),

  // ===== 韵母 (24) — 用读音对应汉字朗读 =====
  LearnItem(subject: 'pinyin', displayText: 'a', subText: 'ā 啊', speakText: '啊', matchTargets: ['a', '啊'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'o', subText: 'ō 喔', speakText: '喔', matchTargets: ['o', '喔'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'e', subText: 'ē 鹅', speakText: '鹅', matchTargets: ['e', '鹅'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'i', subText: 'ī 衣', speakText: '衣', matchTargets: ['i', 'yi', '衣'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'u', subText: 'ū 乌', speakText: '乌', matchTargets: ['u', 'wu', '乌'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ü', subText: 'ǖ 迂', speakText: '迂', matchTargets: ['v', 'u', 'yu', '迂'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ai', subText: 'āi 挨', speakText: '挨', matchTargets: ['ai', '挨'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ei', subText: 'ēi 诶', speakText: '诶', matchTargets: ['ei', '诶'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ui', subText: 'uī 威', speakText: '威', matchTargets: ['ui', 'wei', '威'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ao', subText: 'āo 熬', speakText: '熬', matchTargets: ['ao', '熬'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ou', subText: 'ōu 欧', speakText: '欧', matchTargets: ['ou', '欧'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'iu', subText: 'iū 优', speakText: '优', matchTargets: ['iu', 'you', '优'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ie', subText: 'iē 耶', speakText: '耶', matchTargets: ['ie', 'ye', '耶'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'üe', subText: 'üē 约', speakText: '约', matchTargets: ['ve', 'ue', 'yue', '约'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'er', subText: 'ér 耳', speakText: '耳', matchTargets: ['er', '耳'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'an', subText: 'ān 安', speakText: '安', matchTargets: ['an', '安'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'en', subText: 'ēn 恩', speakText: '恩', matchTargets: ['en', '恩'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'in', subText: 'īn 因', speakText: '因', matchTargets: ['in', 'yin', '因'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'un', subText: 'ūn 温', speakText: '温', matchTargets: ['un', 'wen', '温'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ün', subText: 'ǖn 晕', speakText: '晕', matchTargets: ['vn', 'un', 'yun', '晕'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ang', subText: 'āng 昂', speakText: '昂', matchTargets: ['ang', '昂'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'eng', subText: 'ēng 鞥', speakText: '鞥', matchTargets: ['eng', '鞥'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ing', subText: 'īng 英', speakText: '英', matchTargets: ['ing', 'ying', '英'], category: 'yunmu'),
  LearnItem(subject: 'pinyin', displayText: 'ong', subText: 'ōng 嗡', speakText: '嗡', matchTargets: ['ong', '嗡'], category: 'yunmu'),

  // ===== 整体认读音节 (16) — 用读音对应汉字朗读 =====
  LearnItem(subject: 'pinyin', displayText: 'zhi', subText: 'zhī 知', speakText: '知', matchTargets: ['zhi', '知'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'chi', subText: 'chī 吃', speakText: '吃', matchTargets: ['chi', '吃'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'shi', subText: 'shī 师', speakText: '师', matchTargets: ['shi', '师'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'ri', subText: 'rì 日', speakText: '日', matchTargets: ['ri', '日'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'zi', subText: 'zī 资', speakText: '资', matchTargets: ['zi', '资'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'ci', subText: 'cī 雌', speakText: '雌', matchTargets: ['ci', '雌'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'si', subText: 'sī 思', speakText: '思', matchTargets: ['si', '思'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yi', subText: 'yī 衣', speakText: '衣', matchTargets: ['yi', '衣'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'wu', subText: 'wū 乌', speakText: '乌', matchTargets: ['wu', '乌'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yu', subText: 'yú 鱼', speakText: '鱼', matchTargets: ['yu', '鱼'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'ye', subText: 'yē 耶', speakText: '耶', matchTargets: ['ye', '耶'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yue', subText: 'yuē 月', speakText: '月', matchTargets: ['yue', '月'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yuan', subText: 'yuán 圆', speakText: '圆', matchTargets: ['yuan', '圆'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yin', subText: 'yīn 因', speakText: '因', matchTargets: ['yin', '因'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'yun', subText: 'yūn 云', speakText: '云', matchTargets: ['yun', '云'], category: 'zhengti'),
  LearnItem(subject: 'pinyin', displayText: 'ying', subText: 'yīng 英', speakText: '英', matchTargets: ['ying', '英'], category: 'zhengti'),
];

/// 拼音**声母** → eSpeak 音素串（供英文 Piper 模型直接合成「纯辅音」）。
///
/// 声母的本音是辅音（f 读作 /f/，绝不能读成呼读音「佛 fo」）。
/// 中文 VITS 模型只能按汉字整音节朗读（佛 = fo），无法发孤立辅音，
/// 因此声母走英文 Piper 模型，以 eSpeak 音素串整体作为一个音素 token 合成：
/// - 基础辅音 (b/p/m/f/d/t/n/l/g/k/h/s/w) 取单字符音素，发音内容完全对应；
/// - 破擦/擦音 (j→dʒ、q/ch→tʃ、x/sh→ʃ、zh→dʒ、r→r、z/c→ts) 用 eSpeak 二合音素近似，
///   比整音节「鸡/七/西」更贴近声母本音；y→j 对应半元音 /j/。
/// 韵母 / 整体认读仍用中文模型朗读整音节（呼读音 / 音节），内容已正确，不改。
const Map<String, String> pinyinInitialPhoneme = {
  'b': 'b', 'p': 'p', 'm': 'm', 'f': 'f',
  'd': 'd', 't': 't', 'n': 'n', 'l': 'l',
  'g': 'g', 'k': 'k', 'h': 'h', 's': 's', 'w': 'w', 'y': 'j',
  'j': 'dʒ', 'q': 'tʃ', 'x': 'ʃ',
  'zh': 'dʒ', 'ch': 'tʃ', 'sh': 'ʃ', 'r': 'r', 'z': 'ts', 'c': 'ts',
};

/// 声母发音模式开关 (便于随时在两种方案间切换)：
/// - false (默认)：声母用**汉字呼读音**朗读 (中文模型，如 f→「佛」、b→「波」)；
/// - true ：声母用**纯辅音**朗读 (英文 Piper 模型按 eSpeak 音素合成，如 f→/f/)。
/// 用户反馈先采用文字发音，听感不对再切回纯辅音，故默认 false。
const bool kShengmuPureConsonant = false;
