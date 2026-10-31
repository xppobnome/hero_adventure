# 英雄闯关计划 v1.0.1 发行说明 / Hero Adventure v1.0.1 Release Notes

---

## 🇨🇳 中文

### 标题
**《英雄闯关计划》v1.0.1 —— 学习跟读体验优化 & 稳定性修复**

### 简介
本次为小版本更新，聚焦「学习跟读系统」的体验打磨与真机运行时稳定性修复，建议所有用户升级。

### 本次更新内容
- 🎓 **识字 / 英语 预缓存提前**：进入「地球防卫图」主界面即后台预合成全部朗读内容（离线 TTS 模型预热 + 全条目缓存），进入闯关页点「听一遍」即时发声、零延迟。
- 🔊 **「听一遍」小喇叭动效**：点击后喇叭声波动画改为**仅持续 1 秒**即结束，不再随朗读全程闪烁。
- 📺 **拼音跟读视频优化**：
  - 移除底部蓝色「完成学习」按钮，改为**视频完整播放到结尾**即发奖（避免误触提前发奖）。
  - 进度条**加粗放大**（轨道 16px / 手柄 18px），并支持点击与拖拽定位，方便回看某个声母 / 韵母。
  - 视频来源小字改为「视频来自B站up主续命星期五」（侵权可撤销，点击可打开原视频）。
- 🔧 **稳定性修复**：修复真机运行时喇叭声波动画断言崩溃与布局溢出；提升离线 TTS 音量（中文 / 英文 / 声母纯辅音）。

---

## 🇬🇧 English

### Title
**Hero Adventure v1.0.1 —— Learning Read-Along Polish & Stability Fixes**

### Introduction
A patch release focused on polishing the Learning Read-Along system and fixing runtime crashes on real devices. Recommended for all users.

### What's New
- 🎓 **Earlier pre-caching for Chinese / English**: entering the home map now pre-synthesizes all read-aloud segments in the background (offline TTS warm-up + full cache), so tapping "Listen once" plays instantly with zero delay.
- 🔊 **"Listen once" speaker animation**: the sound-wave animation on the speaker icon now lasts **only 1 second** after tapping, instead of animating for the whole playback.
- 📺 **Pinyin teaching video improvements**:
  - Removed the bottom blue "完成学习 / Finish" button — the reward is now granted when the video plays to the end (prevents accidental early rewards).
  - **Thicker, larger progress bar** (16px track / 18px handle) with tap & drag seeking to revisit any initial / final.
  - Source note changed to "视频来自B站up主续命星期五" (removable on takedown; tappable to open the original).
- 🔧 **Stability fixes**: fixed a real-device crash (speaker waveform assertion) and layout overflow; boosted offline TTS volume (Chinese / English / pure-consonant initials).

---

> 📥 **下载 / Download**：APK 见本 Release 附件（assets）。
> 🏠 源码：https://github.com/xppobnome/hero_adventure ｜ https://gitee.com/xppobnome/hero_adventure
