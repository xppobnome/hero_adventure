# 英雄闯关计划 · Hero Adventure

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Pad-lightgrey?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/Version-1.0.1-E60012?style=for-the-badge" alt="Version" />
</p>

<p align="center">
  <a href="https://github.com/xppobnome/hero_adventure/releases">
    <img src="https://img.shields.io/github/downloads/xppobnome/hero_adventure/total?style=flat-square&logo=github&label=下载量&color=blue" alt="GitHub Downloads" />
  </a>
  <a href="https://github.com/xppobnome/hero_adventure">
    <img src="https://img.shields.io/github/stars/xppobnome/hero_adventure?style=flat-square&logo=github&label=收藏&color=yellow" alt="GitHub Stars" />
  </a>
  <a href="https://github.com/xppobnome/hero_adventure/forks">
    <img src="https://img.shields.io/github/forks/xppobnome/hero_adventure?style=flat-square&logo=github&label=Fork&color=orange" alt="GitHub Forks" />
  </a>
  <a href="https://github.com/xppobnome/hero_adventure">
    <img src="https://img.shields.io/github/license/xppobnome/hero_adventure?style=flat-square&label=License" alt="License" />
  </a>
  <a href="https://gitee.com/xppobnome/hero_adventure">
    <img src="https://img.shields.io/badge/Gitee-镜像仓库-C71D23?style=flat-square&logo=gitee&logoColor=white" alt="Gitee" />
  </a>
</p>

---

## 📖 项目介绍

**《英雄闯关计划》** 是一款面向家庭的跨平台（手机 / 平板）儿童习惯养成应用。项目采用 **「本地优先 + 双轨同步（局域网 / WebDAV）」** 架构，将日常枯燥的任务（如刷牙、整理房间、按时睡觉）包装成一场「化身光之巨人、消灭怪兽」的冒险旅程。

**核心体验**：以「奥特曼宇宙」为默认核心主题，孩子每完成一个打卡任务，就相当于击败一只怪兽、发射一束光线，收获经验值（EXP）与能量币（Coins），并逐步解锁历代英雄卡牌。系统底层预留多主题切换框架，后续版本可无缝接入「机甲战士」「魔法学院」等新主题，持续保持孩子的打卡新鲜感。

### ✨ 核心亮点

- 🦸 **游戏化闯关**：任务即关卡，打卡即战斗，让孩子在冒险中养成好习惯。
- 👨‍👩‍👧‍👦 **一户多宝**：支持同一家庭多个儿童档案，数据完全隔离互不干扰。
- 🔐 **家长安全锁**：4 位 PIN 码防护，防止孩子篡改任务或自我发奖。
- 📊 **数据看板与审批**：家长实时查看打卡热力图、能量币曲线，审核拍照凭证与兑换申请。
- 🔄 **离线优先 + 双轨同步**：本地 Hive 存储，支持局域网二维码直传与 WebDAV 云端备份。
- 📱 **多端适配**：手机 / 平板自适应布局，平板端左右分栏更高效。

---

## 🚀 项目内容

### 技术栈

| 类别 | 技术 | 说明 |
| ---- | ---- | ---- |
| UI 框架 | Flutter | 纯 Dart 实现，一套代码编译 Android / iOS / Pad |
| 状态管理 | Riverpod | 多角色隔离、多儿童状态与主题动态切换 |
| 本地存储 | Hive | 轻量 K-V 数据库，支持 JSON 高效读写，保障离线可用 |
| 屏幕适配 | flutter_screenutil | 手机 / 平板统一缩放机制 |
| 动画动效 | lottie | 奥特曼大招 / 胜利特效全屏动画 |
| 音效 | just_audio | 变身、光线攻击、怪兽吼叫等音效 |
| 二维码 | qr_flutter + mobile_scanner | 局域网面对面同步的生成与扫描 |
| 云同步 | http（WebDAV 协议） | 坚果云 / 私人 NAS 云端备份 |
| 图片处理 | image_picker + image | 拍照凭证、头像选择与压缩 |
| 数据打包 | archive | 备份压缩包打包 / 解包 |

### 架构分层（Clean Architecture）

1. **表现层（Presentation）**：UI 视图、Lottie 动画、路由导航。
2. **业务逻辑层（Domain）**：Riverpod 状态控制器、打卡验证逻辑、经验 / 积分计算、兑换审批流。
3. **数据层（Data）**：Hive 本地持久化、JSON 序列化、WebDAV 通信、局域网直传协议。

---

## ✅ 已实现的项目

### 初始化与账号权限
- [x] 首次启动创建「本地家庭档案」，卸载重装可通过 WebDAV 找回
- [x] 家庭主账号 + 多儿童号（一户多宝）自由切换
- [x] 4 位 PIN 码安全锁，进入家长控制台 / 切换家长号时强制验证
- [x] PIN 码解除绑定（忘记密码时的安全重置流程）

### 家长端控制台
- [x] 任务 CRUD：新增、编辑、删除任务
- [x] 任务属性：名称、怪兽图标、奖励 EXP、奖励能量币、周期、拍照凭证开关
- [x] 任务周期：每日 / 每周 / 单次，支持「打卡一周」「选择指定日期」
- [x] 奖励商城管理：配置现实奖励及对应消耗能量币，支持「免审核」即时兑换、点击卡片编辑
- [x] 数据看板：累计打卡、本周打卡、当前等级、能量币余额
- [x] 审批中心：拍照凭证审核、奖励兑换申请审批（同意 / 驳回）+ 审批历史记录
- [x] 家长查看儿童任务进度
- [x] 打卡记录：按儿童筛选、CSV 导出

### 儿童端闯关系统（奥特曼主题）
- [x] 地球防卫地图：读取任务列表，动态生成关卡节点与当前状态点
- [x] 打卡交互闭环：点击节点 → 任务详情 → 光线攻击 → Lottie 怪兽爆炸动画 + 音效
- [x] 状态机流转：普通任务直接完成；需拍照任务进入「待审核」状态
- [x] 英雄图鉴库：按累计经验值升级，逐步解锁历代奥特曼（前密后疏的解锁等级曲线）
- [x] 奖励兑换：儿童用能量币兑换现实奖励，提交家长审批；兑换记录页
- [x] 拍照打卡：image_picker 拍照 / 相册选择凭证
- [x] 数学闯关答题（Math Quiz），平板横屏左右分栏布局
- [x] 预设任务模板（Preset Templates）多选快速建任务

### 儿童端学习跟读系统（离线 TTS）
- [x] 学拼音 / 识字 / 学英语 三学科跟读闯关（统一 `LearnItem` 字库 + `Task` 配置）
- [x] **识字 / 英语 纯离线神经网络 TTS**（Sherpa-ONNX 中文 VITS + 英文 Piper 双模型），**全程 Sherpa**，无需联网即可稳定朗读单字 / 单词
- [x] **拼音模块改为播放跟读教学视频**（内置 MP4，进入即自动播放，可暂停 / 拖拽进度；视频完整播放到结尾即发奖，底部不再保留「完成学习」按钮）；视频来源小字标注「视频来自B站up主续命星期五」，可点击打开原视频（BV1Fe411N7my）
- [x] 中文补读「词语」并在词语上方标注带声调拼音；英文补读中文释义并标注美式音标（IPA）+ 释义拼音
- [x] 「听一遍」极速响应：进页面预加载**全部**朗读内容（预合成缓存）+ 在途合成去重，点击即时发声；喇叭图标在朗读 / 加载时动态变化；后台预合成走**串行队列**，避免瞬间海量请求挤爆 TTS isolate 导致超时
- [x] 三学科闯关的任务配置与打卡记录均纳入全量备份（见下方数据同步引擎），换机 / 恢复不丢失
- [x] 字库扩充：**识字 404 字**（覆盖动物 / 食物果蔬 / 天气季节 / 衣物 / 人物称谓 / 学习文具 / 交通 / 自然景物等主题）、**英语 477 词**（覆盖星期月份 / 职业 / 运动 / 天气季节 / 情绪 / 衣物 / 水果蔬菜 / 地点建筑 / 抽象名词 / 副词连接等主题），拼音保持教学大纲完整 63 项

### 数据同步引擎
- [x] 局域网面对面传输：二维码生成 / 扫描，一键推送 / 拉取完整 JSON 库
- [x] WebDAV 云端同步：账号密码备份、Last-Modified 对比合并
- [x] 退出 / 进入 App 时自动数据同步
- [x] 强制同步开关：打卡、兑换、审核通过等关键操作自动上传
- [x] 完整备份扩展：`.herobackup` 压缩包（含 data.json + 图片 + 拼音 / 识字 / 英语闯关任务与打卡记录），备份 / 恢复

### 视听特效与主题
- [x] 奥特曼主题配色（经典红 `#E60012` / 太空银 / 计时器蓝 `#00A0E9`）
- [x] 奥特曼特效、音效、背景、动画（变身 / 光线 / 胜利）
- [x] 开屏启动动画
- [x] 主题切换框架预留（`currentTheme` 字段，后续接入 mecha / magic）

### 多端适配与个性化
- [x] 手机单列 / 平板左右分栏（`LayoutBuilder` + `NavigationRail`）
- [x] 平板端 PIN 输入、引导流程横竖屏适配
- [x] 平板横屏适配：儿童打卡看板、日历、数学闯关左右布局、家长各列表
- [x] 打卡记录导出到公共目录
- [x] 桌面快捷方式（Pinned Shortcut）：自定义图标 + 名字（在家长设置中开启）
- [x] 自定义图标 / 名字应用到启动图与「关于」页
- [x] 儿童头像与自定义图标图片互斥（避免歧义）
- [x] 调试模式（隐藏入口：关于页连续点击版本号 6 次进入）：儿童等级 / 能量币调试、一键解锁全部英雄、解除设备绑定、一键复原
- [x] 调试模式内置「开启日志」开关：开启后把语音下载 / 发音等详细日志写入手机公共「下载 / Download」目录（`hero_adventure_log_*.txt`），无需 adb 即可取日志排查问题
- [x] 版本自动检查更新：GitHub / Gitee 双源（默认 Gitee），检测到新版本自动下载 APK 到公共下载目录并触发安装，支持永久忽略 / 下个版本提醒

---

## ⏳ 未实现的项目

- [ ] 更丰富的界面交互动画（打卡流程、页面切换过渡）
- [ ] 更多奥特曼素材（更多英雄立绘、怪兽图标、背景图）
- [ ] 其他主题（机甲战士 `mecha`、魔法学院 `magic` 等，框架已预留）
- [ ] 更多打卡声效（更多英雄专属技能音效）

---

## 🗺️ 后续要添加的项目

- 🎨 **新主题接入**：机甲战士、魔法学院等（利用 `currentTheme` 动态切换框架）
- 🎬 **界面动画完善**：打卡、兑换、升级等流程的交互动效
- 🦸 **英雄素材扩充**：更多奥特曼卡牌、怪兽图标与背景素材
- 🔊 **音效扩充**：更多英雄专属技能音效、节日限定音效
- 📈 **数据可视化增强**：更丰富的打卡热力图与成长曲线
- ☁️ **多端云同步优化**：更智能的冲突合并策略
- 🎁 **成就 / 徽章系统**：连续打卡、里程碑成就奖励
- 👨‍👩‍👧‍👦 **家长多设备管理**：更便捷的家庭成员邀请与授权

---

## 🛠️ 构建与运行

### 环境要求

- Flutter SDK（Dart SDK ≥ 3.10.0）
- Android Studio / Xcode

### 获取依赖

```bash
flutter pub get
```

> **离线 TTS 模型改为远程按需下载（不进 APK、不进 git）**：中文模型 `vits-zh-hf-fanchen-C.onnx`（约 116MB）与英文模型 `en_US-libritts_r-medium.onnx`（约 75MB）体积过大，已从 APK 与仓库中移除，改为**首次使用时从 Cloudflare R2 CDN 按需下载**（`tts.cloudvl.de5.net`，见 `lib/core/services/sherpa_tts_service.dart` 的 `TtsModelStore`）。首次进入识字 / 英语模块会弹出「需要下载语音资源」提示并显示进度条，下载完成后二次进入零等待。若远程下载失败（无网络），应用会自动降级为系统 TTS。模型来源：Sherpa-ONNX 官方模型库（`k2-fsa/sherpa-onnx` Releases / Hugging Face `csukuangfj`）。

> **拼音跟读教学视频未纳入 git**：`assets/video/pinyin_read_along.mp4`（约 15MB）同样因体积不随仓库分发。请将该文件放入 `assets/video/` 目录，拼音模块方可播放视频；缺失时拼音模块会显示加载失败（不影响识字 / 英语模块）。来源：哔哩哔哩 BV1Fe411N7my，up 主「续命星期五」（侵权可撤销）。

### 运行

```bash
flutter run
```

### Android 签名打包（Release）

> ⚠️ 签名密钥文件（`android/app/hero_adventure.jks`）与密钥配置（`android/key.properties`）为**敏感文件**，已加入 `.gitignore`，**请勿提交到 Gitee / GitHub**。

1. 在 `android/key.properties` 中配置签名信息（参考下方模板）：

```properties
storePassword=<store 密码>
keyPassword=<alias 密码>
keyAlias=<别名>
storeFile=hero_adventure.jks
```

2. 构建 Release 包：

```bash
flutter build apk --release
```

> 若 `key.properties` 不存在，构建会自动回退到 debug 签名，保证编译不中断。

---

## 📂 项目结构

```
hero_adventure/
├── android/                 # Android 原生工程（含签名配置）
├── lib/
│   ├── core/                # 核心工具（音效、同步、备份、原生桥接等）
│   ├── data/                # 数据层（Hive 持久化、模型）
│   ├── domain/              # 业务逻辑层（Riverpod providers、英雄系统）
│   └── features/
│       ├── auth/            # 鉴权与引导（家庭档案、PIN）
│       ├── child_adventure/ # 儿童端闯关（地图、图鉴、商城、答题）
│       ├── parent_console/  # 家长端控制台（看板、审批、设置）
│       ├── shared/          # 共享组件（设置卡片、关于、调试）
│       └── sync/            # 同步引擎（二维码、WebDAV）
├── assets/                  # 静态资源（音效、英雄、Lottie、图片）
├── pubspec.yaml
└── README.md
```

---

## ⭐ Star History

<p align="center">
  <a href="https://star-history.com/#xppobnome/hero_adventure&Date">
    <img src="https://api.star-history.com/svg?repos=xppobnome/hero_adventure&type=Date" alt="Star History Chart" width="600" />
  </a>
</p>

---

## 📄 许可证

本项目仅供学习与个人使用，请遵循相关开源协议与素材版权规范。
