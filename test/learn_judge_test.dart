import 'package:flutter_test/flutter_test.dart';
import 'package:hero_adventure/data/learn_content/learn_item.dart';
import 'package:hero_adventure/domain/learn_judge.dart';

void main() {
  group('LearnJudge.normalizePinyin', () {
    test('去声调', () {
      expect(LearnJudge.normalizePinyin('bō'), 'bo');
      expect(LearnJudge.normalizePinyin('zhī'), 'zhi');
      expect(LearnJudge.normalizePinyin('rén'), 'ren');
      expect(LearnJudge.normalizePinyin('shuǐ'), 'shui');
    });

    test('ü 系列归一化为 v', () {
      expect(LearnJudge.normalizePinyin('ü'), 'v');
      expect(LearnJudge.normalizePinyin('ǖ'), 'v');
      expect(LearnJudge.normalizePinyin('ǘ'), 'v');
      expect(LearnJudge.normalizePinyin('ǚ'), 'v');
      expect(LearnJudge.normalizePinyin('ǜ'), 'v');
      expect(LearnJudge.normalizePinyin('lǜ'), 'lv');
      expect(LearnJudge.normalizePinyin('nǚ'), 'nv');
    });

    test('大写转小写 + 去空格', () {
      expect(LearnJudge.normalizePinyin('Rén'), 'ren');
      expect(LearnJudge.normalizePinyin('a b'), 'ab');
      expect(LearnJudge.normalizePinyin(' z h '), 'zh');
    });
  });

  group('LearnJudge.normalizeEnglish', () {
    test('lowercase + trim', () {
      expect(LearnJudge.normalizeEnglish('  Apple  '), 'apple');
      expect(LearnJudge.normalizeEnglish('GOOD'), 'good');
    });

    test('折叠连续空格', () {
      expect(LearnJudge.normalizeEnglish('good   morning'), 'good morning');
      expect(LearnJudge.normalizeEnglish('a  b'), 'a b');
    });
  });

  group('LearnJudge.isMatch', () {
    const pinyinB = LearnItem(
      subject: 'pinyin',
      displayText: 'b',
      speakText: '波',
      matchTargets: ['b', 'bo', '波'],
      category: 'shengmu',
    );

    test('拼音声母：字母、呼读音、同音汉字均命中', () {
      expect(LearnJudge.isMatch(recognized: 'b', item: pinyinB), isTrue);
      expect(LearnJudge.isMatch(recognized: 'bō', item: pinyinB), isTrue);
      expect(LearnJudge.isMatch(recognized: 'bo', item: pinyinB), isTrue);
      expect(LearnJudge.isMatch(recognized: '波', item: pinyinB), isTrue);
      expect(LearnJudge.isMatch(recognized: '玻', item: pinyinB), isTrue);
      expect(LearnJudge.isMatch(recognized: 'bee', item: pinyinB), isFalse);
    });

    const hanziRen = LearnItem(
      subject: 'hanzi',
      displayText: '人',
      speakText: '人',
      matchTargets: ['ren'],
    );

    test('识字：声调无关匹配', () {
      expect(LearnJudge.isMatch(recognized: 'rén', item: hanziRen), isTrue);
      expect(LearnJudge.isMatch(recognized: 'ren', item: hanziRen), isTrue);
      expect(LearnJudge.isMatch(recognized: 'rén men', item: hanziRen), isFalse);
    });

    const pinyinU = LearnItem(
      subject: 'pinyin',
      displayText: 'ü',
      speakText: 'ü',
      matchTargets: ['v', 'u'],
      category: 'yunmu',
    );

    test('韵母 ü：容纳 v/u 变体', () {
      expect(LearnJudge.isMatch(recognized: 'ü', item: pinyinU), isTrue);
      expect(LearnJudge.isMatch(recognized: 'u', item: pinyinU), isTrue);
      expect(LearnJudge.isMatch(recognized: 'v', item: pinyinU), isTrue);
    });

    const englishApple = LearnItem(
      subject: 'english',
      displayText: 'apple',
      speakText: 'apple',
      matchTargets: ['apple'],
    );

    test('英语：大小写/空格不敏感', () {
      expect(LearnJudge.isMatch(recognized: 'APPLE', item: englishApple), isTrue);
      expect(LearnJudge.isMatch(recognized: ' apple ', item: englishApple), isTrue);
      expect(LearnJudge.isMatch(recognized: 'app le', item: englishApple), isFalse);
    });

    test('空识别结果不误判', () {
      expect(LearnJudge.isMatch(recognized: '', item: pinyinB), isFalse);
      expect(LearnJudge.isMatch(recognized: '   ', item: englishApple), isFalse);
    });

    test('识字：识别返回同音汉字也能匹配', () {
      // 儿童读「人」，识别可能返回汉字「人」而非拼音 ren
      expect(LearnJudge.isMatch(recognized: '人', item: hanziRen), isTrue);
      // 「们」与「人」拼音不同，不应误判
      expect(LearnJudge.isMatch(recognized: '们', item: hanziRen), isFalse);
    });
  });
}
