# 英雄闯关计划 v1.0.1 发行说明 / Hero Adventure v1.0.1 Release Notes

---

## 🇨🇳 中文

### 标题
**《英雄闯关计划》v1.0.1 —— 学习跟读系统大升级 & 稳定性修复**

### 简介
本次更新聚焦「学习跟读系统」的深度打磨：大幅扩充识字与英语词库、重构离线语音模型分发方式、修复多项真机运行时问题，建议所有用户升级。

### ✨ 学习内容扩充
- 🀄 **识字字库扩充至 404 字**：在原有基础上新增动物、食物果蔬、天气季节、衣物配饰、数字数量、颜色、情感品质、动作、人物称谓、学习文具、交通出行、自然景物、抽象词等十余个主题约 150 个常用字，覆盖更全面的启蒙识字场景。
- 🔤 **英语词库扩充至 477 词**：新增星期与月份、职业、运动、天气季节、情绪、衣物、水果蔬菜、食物、动物、身体、学校、家庭生活、地点建筑、抽象名词、动词、形容词、副词与连接词、颜色、节日等主题约 227 个高频词。
- 🔠 拼音保持教学大纲完整的 63 项（声母 23 + 韵母 24 + 整体认读 16）。

### 📦 离线语音模型按需下载（体积大瘦身）
- 🎯 **APK 大幅瘦身**：中文（116MB）+ 英文（75MB）两个离线 TTS 模型不再打包进 APK，改为**首次使用时从云端 CDN 按需下载**，安装包体积显著减小。
- 📡 **首次进入智能提示**：进入识字 / 英语模块若缺少语音资源，会弹出「需要下载语音资源」提示并展示实时进度条；下载完成后二次进入零等待。
- 🛡️ **自动降级兜底**：无网络或下载失败时自动降级为系统 TTS，功能不受阻断。

### 🎓 学习跟读体验优化
- 🎧 **「听一遍」极速响应**：进入「地球防卫图」主界面即后台预合成全部朗读内容（离线 TTS 预热 + 全条目缓存），进入闯关页点「听一遍」即时发声、零延迟。
- 🔧 **修复预合成超时问题**：后台预合成改为**串行队列**，避免一次性派发海量请求挤爆 TTS 引擎导致大面积「合成超时」，现在发音稳定可靠。
- 🔊 **「听一遍」小喇叭动效**：点击后喇叭声波动画仅持续 1 秒即结束，不再随朗读全程闪烁。
- 📺 **拼音跟读视频优化**：
  - 移除底部蓝色「完成学习」按钮，改为**视频完整播放到结尾**即发奖。
  - 进度条加粗放大，支持点击与拖拽定位，方便回看某个声母 / 韵母。
  - 视频来源小字标注「视频来自B站up主续命星期五」（侵权可撤销，点击可打开原视频）。
- 🎙️ **学习跟读配置更灵活**：识字 / 英语可自定义「跟读顺序」（顺序 / 随机）与「每天跟读数量」，拼音固定顺序读全部。

### 🛠️ 调试与日志
- 🐛 **日志功能迁入调试模式**：在「关于」页连续点击版本号 6 次进入调试模式，可开启「详细日志」开关；开启后语音下载 / 发音等关键日志自动写入手机公共「下载 / Download」目录（`hero_adventure_log_*.txt`），无需 adb 即可取日志排查问题。
- 🔍 调试模式同时提供儿童等级 / 能量币调试、一键解锁全部英雄、解除设备绑定、一键复原等能力。

### 🔧 稳定性与其它修复
- 🔐 **调试运行与正式打包统一签名**：`flutter run` 调试运行使用与正式包相同的签名，调试时公共目录访问等行为与正式包完全对齐。
- 🐞 修复真机运行时喇叭声波动画断言崩溃与布局溢出；提升离线 TTS 音量（中文 / 英文 / 声母纯辅音）。
- 📝 修正应用版本号显示（1.0.0 Beta → 1.0.1）。

---

## 🇬🇧 English

### Title
**Hero Adventure v1.0.1 —— Learning Read-Along Major Upgrade & Stability Fixes**

### Introduction
A substantial update focused on the Learning Read-Along system: greatly expanded Chinese-character and English word banks, a redesigned offline speech-model distribution, and many real-device fixes. Recommended for all users.

### ✨ Expanded Learning Content
- 🀄 **404 Chinese characters**: added ~150 common characters across 10+ themes (animals, food, weather & seasons, clothing, numbers, colors, emotions, actions, people, school supplies, transport, nature, abstract words) for a broader literacy foundation.
- 🔤 **477 English words**: added ~227 high-frequency words across themes (weekdays & months, jobs, sports, weather & seasons, emotions, clothing, fruits & vegetables, food, animals, body, school, home life, places, abstract nouns, verbs, adjectives, adverbs & conjunctions, colors, festivals).
- 🔠 Pinyin remains the complete 63-item syllabus set (23 initials + 24 finals + 16 whole-syllable).

### 📦 On-demand Speech-Model Download (major size reduction)
- 🎯 **Much smaller APK**: the Chinese (116MB) and English (75MB) offline TTS models are no longer bundled; they are **downloaded on first use from a cloud CDN**.
- 📡 **Smart first-run prompt**: entering the Chinese-character / English module without the speech resources shows a "need to download speech resources" dialog with a real-time progress bar; subsequent entries are instant.
- 🛡️ **Automatic fallback**: gracefully falls back to system TTS when offline or the download fails.

### 🎓 Learning Read-Along Improvements
- 🎧 **Instant "Listen once"**: entering the home map pre-synthesizes all read-aloud segments in the background (offline TTS warm-up + full cache), so tapping "Listen once" plays instantly with zero delay.
- 🔧 **Fixed pre-synthesis timeouts**: background pre-synthesis now runs through a **serial queue**, avoiding a burst of requests that previously flooded the TTS engine and caused widespread "synthesis timeout" — pronunciation is now stable.
- 🔊 **"Listen once" speaker animation**: the sound-wave animation lasts only 1 second after tapping.
- 📺 **Pinyin teaching video improvements**: reward granted when the video plays to the end (no more "Finish" button); thicker progress bar with tap & drag seeking; source attributed to Bilibili UP "续命星期五" (removable on takedown).
- 🎙️ **Flexible read-along config**: Chinese-character / English tasks can customize read order (ordered / random) and daily count; Pinyin always reads all items in order.

### 🛠️ Debugging & Logging
- 🐛 **Logging moved into Debug Mode**: tap the version number 6 times on the About page to enter Debug Mode, then enable the "detailed logging" switch; key logs (speech download / pronunciation) are written to the phone's public "Download" folder (`hero_adventure_log_*.txt`) — no adb required to retrieve logs.
- 🔍 Debug Mode also provides child level / coin tweaking, unlock-all-heroes, unbind device, and one-tap restore.

### 🔧 Stability & Other Fixes
- 🔐 **Debug & release share the same signing key**: `flutter run` now uses the same signature as the release build.
- 🐞 Fixed a real-device speaker-waveform assertion crash and layout overflow; boosted offline TTS volume.
- 📝 Fixed the version-name display (1.0.0 Beta → 1.0.1).

---

> 📥 **下载 / Download**：APK 见本 Release 附件（assets）。
> 🏠 源码：https://github.com/xppobnome/hero_adventure ｜ https://gitee.com/xppobnome/hero_adventure
