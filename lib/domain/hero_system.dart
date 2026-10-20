/// 等级与英雄图鉴系统 (奥特曼主题)。
///
/// 集中定义等级曲线、英雄解锁规则，供看板、儿童端、家长端复用。

/// 满级 (最高等级)。
const int maxLevel = 100;

/// 每级所需经验值：简单线性曲线，每级递增。
/// 第 1 级 -> 第 2 级需 100 EXP，之后每级递增 50。
int expForLevel(int level) {
  if (level <= 1) return 0;
  return 100 + (level - 2) * 50;
}

/// 根据累计经验值计算当前等级 (封顶 [maxLevel])。
int levelFromExp(int exp) {
  int level = 1;
  int remaining = exp;
  while (level < maxLevel && remaining >= expForLevel(level + 1)) {
    remaining -= expForLevel(level + 1);
    level++;
  }
  return level;
}

/// 计算当前等级进度 (0.0 ~ 1.0)。
double levelProgress(int exp) {
  final level = levelFromExp(exp);
  if (level >= maxLevel) return 1.0;
  final currentNeed = expForLevel(level + 1);
  if (currentNeed <= 0) return 1.0;
  final into = exp - _expAtLevelStart(level);
  return (into / currentNeed).clamp(0.0, 1.0);
}

/// 达到某等级所需的累计经验值。
int _expAtLevelStart(int level) {
  int total = 0;
  for (int l = 2; l <= level; l++) {
    total += expForLevel(l);
  }
  return total;
}

/// 英雄图鉴数据：随等级解锁。
class HeroEntry {
  final String id; // 唯一标识 (用于「当前出战英雄」持久化)
  final String name;
  final String title; // 称号
  final int unlockLevel; // 解锁所需等级
  final String colorHex; // 主题色 (用于占位绘制/高亮)
  final String desc;
  final String imageAsset; // 英雄立绘 (PNG，缺失时回退到程序绘制)
  final String skillSoundAsset; // 释放技能音效 (MP3/WAV)
  final String skillAnimAsset; // 释放技能动画 (Lottie JSON，缺失回退程序绘制)

  const HeroEntry({
    required this.id,
    required this.name,
    required this.title,
    required this.unlockLevel,
    required this.colorHex,
    required this.desc,
    this.imageAsset = '',
    this.skillSoundAsset = '',
    this.skillAnimAsset = '',
  });
}

/// 按 id 查找英雄，找不到返回 null。
HeroEntry? heroById(String id) {
  for (final h in heroCatalog) {
    if (h.id == id) return h;
  }
  return null;
}

/// 当前等级能解锁的最高级英雄 (用于「按等级自动出战」兜底)。
HeroEntry highestUnlockedHero(int level) {
  HeroEntry result = heroCatalog.first;
  for (final h in heroCatalog) {
    if (h.unlockLevel <= level) result = h;
  }
  return result;
}

/// 奥特曼英雄图鉴列表 (按解锁等级升序)。
///
/// 素材约定：每个英雄专属图片/音效/动画放在
///   assets/heroes/<id>/<id>.png | <id>_skill.mp3 | <id>_skill.json
/// 放入真实文件后自动生效；未放文件时回退到程序绘制的风格化头像。
const List<HeroEntry> heroCatalog = [
  HeroEntry(
    id: 'ace',
    name: '艾斯奥特曼',
    title: '光线之王',
    unlockLevel: 1,
    colorHex: 'E6483D',
    desc: '光线技大师，拥有多彩必杀光线，粉碎一切邪恶。',
    imageAsset: 'assets/heroes/ace/ace.png',
    skillSoundAsset: 'assets/heroes/ace/ace_skill.mp3',
    skillAnimAsset: 'assets/heroes/ace/ace_skill.json',
  ),
  HeroEntry(
    id: 'taro',
    name: '泰罗奥特曼',
    title: '光之王子',
    unlockLevel: 12,
    colorHex: 'E6483D',
    desc: '奥特之父之子，斯特利姆光线威力惊人。',
    imageAsset: 'assets/heroes/taro/taro.png',
    skillSoundAsset: 'assets/heroes/taro/taro_skill.mp3',
    skillAnimAsset: 'assets/heroes/taro/taro_skill.json',
  ),
  HeroEntry(
    id: 'leo',
    name: '雷欧奥特曼',
    title: '格斗之王',
    unlockLevel: 24,
    colorHex: 'C0C0C0',
    desc: '狮子座星球的王子，体术格斗的最强者。',
    imageAsset: 'assets/heroes/leo/leo.png',
    skillSoundAsset: 'assets/heroes/leo/leo_skill.mp3',
    skillAnimAsset: 'assets/heroes/leo/leo_skill.json',
  ),
  HeroEntry(
    id: 'mebius',
    name: '梦比优斯奥特曼',
    title: '无限之光',
    unlockLevel: 36,
    colorHex: 'E6483D',
    desc: '年轻的地球守护者，与伙伴共同成长。',
    imageAsset: 'assets/heroes/mebius/mebius.png',
    skillSoundAsset: 'assets/heroes/mebius/mebius_skill.mp3',
    skillAnimAsset: 'assets/heroes/mebius/mebius_skill.json',
  ),
  HeroEntry(
    id: 'tiga',
    name: '迪迦奥特曼',
    title: '光的化身',
    unlockLevel: 50,
    colorHex: '00A0E9',
    desc: '三形态变换，跨越三千万年的传说英雄。',
    imageAsset: 'assets/heroes/tiga/tiga.png',
    skillSoundAsset: 'assets/heroes/tiga/tiga_skill.mp3',
    skillAnimAsset: 'assets/heroes/tiga/tiga_skill.json',
  ),
  HeroEntry(
    id: 'zero',
    name: '赛罗奥特曼',
    title: '最强战士',
    unlockLevel: 65,
    colorHex: '00A0E9',
    desc: '赛文之子，穿越次元的宇宙最强战斗天才。',
    imageAsset: 'assets/heroes/zero/zero.png',
    skillSoundAsset: 'assets/heroes/zero/zero_skill.mp3',
    skillAnimAsset: 'assets/heroes/zero/zero_skill.json',
  ),
  HeroEntry(
    id: 'zetta',
    name: '泽塔奥特曼',
    title: '赛罗的徒弟',
    unlockLevel: 82,
    colorHex: '00A0E9',
    desc: '热血的新生代战士，奥特泽塔光线闪耀宇宙。',
    imageAsset: 'assets/heroes/zetta/zetta.png',
    skillSoundAsset: 'assets/heroes/zetta/zetta_skill.mp3',
    skillAnimAsset: 'assets/heroes/zetta/zetta_skill.json',
  ),
  HeroEntry(
    id: 'king',
    name: '奥特之王',
    title: '传说中的王者',
    unlockLevel: 100,
    colorHex: 'FFC107',
    desc: '光之国传说中的王者，拥有无与伦比的至高力量。',
    imageAsset: 'assets/heroes/king/king.png',
    skillSoundAsset: 'assets/heroes/king/king_skill.mp3',
    skillAnimAsset: 'assets/heroes/king/king_skill.json',
  ),
];
