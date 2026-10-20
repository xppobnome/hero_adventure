# 英雄素材目录说明

本目录存放每个奥特曼英雄的**专属素材**。放入真实文件后应用会自动加载，
未放入时回退到程序绘制的风格化头像与通用特效。

## 目录结构（每个英雄一个子目录，顺序即解锁顺序 1~8）

```
assets/heroes/
├── ace/      # 艾斯奥特曼 (1)
├── taro/     # 泰罗奥特曼 (2)
├── leo/      # 雷欧奥特曼 (3)
├── mebius/   # 梦比优斯奥特曼 (4)
├── tiga/     # 迪迦奥特曼 (5)
├── zero/     # 赛罗奥特曼 (6)
├── zetta/    # 泽塔奥特曼 (7)
└── king/     # 奥特之王 (8)
```

## 每个英雄目录内可放置的文件（文件名需与 hero_system.dart 中约定一致）

以艾斯奥特曼 `ace/` 为例：

| 文件 | 用途 | 约定文件名 |
|------|------|-----------|
| 立绘图片 | 图鉴/打卡展示 | `ace.png`（透明背景 PNG 最佳） |
| 技能音效 | 打卡释放技能声音 | `ace_skill.mp3`（或 .wav） |
| 技能动画 | 打卡释放技能动画 | `ace_skill.json`（Lottie 格式） |

其余英雄同理，把 `ace` 换成对应英雄 id：

- 泰罗 → `taro/taro.png`、`taro_skill.mp3`、`taro_skill.json`
- 雷欧 → `leo/leo.png`、`leo_skill.mp3`、`leo_skill.json`
- 梦比优斯 → `mebius/mebius.png`、`mebius_skill.mp3`、`mebius_skill.json`
- 迪迦 → `tiga/tiga.png`、`tiga_skill.mp3`、`tiga_skill.json`
- 赛罗 → `zero/zero.png`、`zero_skill.mp3`、`zero_skill.json`
- 泽塔 → `zetta/zetta.png`、`zetta_skill.mp3`、`zetta_skill.json`
- 奥特之王 → `king/king.png`、`king_skill.mp3`、`king_skill.json`

## 通用音效（可选替换）

`assets/audio/` 下可放置全局音效，作为英雄专属音效缺失时的回退：

- `beam_attack.mp3` — 光线攻击通用音效
- `victory.mp3` — 胜利/升级音效
- `transform.mp3` — 变身音效
- `error.mp3` — 报错/警报音效

## 版权提醒

请确保你放入的素材拥有合法使用授权（本项目默认不含任何受版权保护的真实
奥特曼图片/原声，仅提供程序绘制的风格化占位视觉）。
