import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hero_adventure/data/learn_content/learn_item.dart';
import 'package:hero_adventure/domain/learn_quiz.dart';

void main() {
  group('LearnQuizGenerator.generate', () {
    test('数量合法时返回去重的指定数量条目', () {
      final items = LearnQuizGenerator(
        subject: LearnSubjects.pinyin,
        scope: 'all',
        count: 50,
        rng: math.Random(1),
      ).generate();

      expect(items.length, 50);
      final unique = items.map((e) => e.displayText).toSet();
      expect(unique.length, 50, reason: '抽题不应重复');
    });

    test('数量超过字库时返回全部 (不重复)', () {
      final items = LearnQuizGenerator(
        subject: LearnSubjects.pinyin,
        scope: 'all',
        count: 99,
        rng: math.Random(2),
      ).generate();

      expect(items.length, 63, reason: '拼音全表共 63 项');
      final unique = items.map((e) => e.displayText).toSet();
      expect(unique.length, 63);
    });

    test('拼音 scope 不再过滤 (统一返回全部拼音)', () {
      final items = LearnQuizGenerator(
        subject: LearnSubjects.pinyin,
        scope: 'shengmu',
        count: 10,
        rng: math.Random(3),
      ).generate();

      expect(items, isNotEmpty);
      expect(items.length, 10);
      expect(items.every((e) => e.subject == LearnSubjects.pinyin), isTrue);
    });

    test('顺序模式：返回字库全部条目 (包含所有拼音)', () {
      final items = LearnQuizGenerator(
        subject: LearnSubjects.pinyin,
        scope: 'all',
        count: 5,
        ordered: true,
      ).generate();

      expect(items.length, 63, reason: '顺序模式应包含所有 63 个拼音');
      // 拼音表前 5 项应为声母 b/p/m/f/d
      expect(items.map((e) => e.displayText).take(5).toList(), ['b', 'p', 'm', 'f', 'd']);
    });

    test('识字/英语 scope=all 返回对应字库', () {
      final hanzi = LearnQuizGenerator(
        subject: LearnSubjects.hanzi,
        scope: 'all',
        count: 10,
        rng: math.Random(4),
      ).generate();
      expect(hanzi.length, 10);
      expect(hanzi.every((e) => e.subject == LearnSubjects.hanzi), isTrue);

      final english = LearnQuizGenerator(
        subject: LearnSubjects.english,
        scope: 'all',
        count: 10,
        rng: math.Random(5),
      ).generate();
      expect(english.length, 10);
      expect(english.every((e) => e.subject == LearnSubjects.english), isTrue);
    });

    test('未知学科返回空列表', () {
      final items = LearnQuizGenerator(
        subject: 'unknown',
        scope: 'all',
        count: 10,
      ).generate();
      expect(items, isEmpty);
    });

    test('非法数量按 1 兜底', () {
      final items = LearnQuizGenerator(
        subject: LearnSubjects.pinyin,
        scope: 'all',
        count: 0,
        rng: math.Random(6),
      ).generate();
      expect(items.length, 1);
    });
  });

  group('isLearnPassed', () {
    test('达标边界：80% 需 8/10', () {
      expect(isLearnPassed(8, 10, 80), isTrue);
      expect(isLearnPassed(7, 10, 80), isFalse);
    });

    test('60% 需 ceil(3.0)=3/5', () {
      expect(isLearnPassed(3, 5, 60), isTrue);
      expect(isLearnPassed(2, 5, 60), isFalse);
    });

    test('100% 需全对', () {
      expect(isLearnPassed(1, 1, 100), isTrue);
      expect(isLearnPassed(0, 1, 100), isFalse);
    });

    test('空集 / 非法入参不误发奖', () {
      expect(isLearnPassed(0, 0, 80), isFalse);
      expect(isLearnPassed(1, 0, 80), isFalse);
      expect(isLearnPassed(-1, 10, 80), isFalse);
    });

    test('阈值越界时安全夹取', () {
      expect(isLearnPassed(10, 10, 0), isTrue, reason: '0 夹取为 1%，全对可通过');
      expect(isLearnPassed(10, 10, 150), isTrue, reason: '150 夹取为 100%');
    });
  });
}
