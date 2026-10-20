# assets/audio

此目录用于存放奥特曼主题的音效资源（通用音效，作为英雄专属音效缺失时的回退）：

- beam_attack.mp3 —— 光线攻击/放技能通用音效（对应「奥特曼放技能通用」）
- victory.mp3 —— 胜利/升级音效（对应「胜利音效」）
- transform.mp3 —— 变身/预警音效（对应「奥特曼红灯」）
- error.mp3 —— 报错/警报音效（对应「失败音效」）

当前版本在 `lib/core/utils/audio_manager.dart` 中已实现双轨策略：
优先用 just_audio 播放真实音频，资源缺失时回退到系统提示音 + 震动反馈。

英雄专属音效位于 `assets/heroes/<id>/<id>_skill.mp3`，打卡时按当前选中英雄
优先播放专属音效，缺失时回退到本目录的 `beam_attack.mp3`。
