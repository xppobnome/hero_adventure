import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:piper_phonemize/piper_phonemize.dart' as piper;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../data/learn_content/learn_item.dart';
import '../utils/app_logger.dart';

/// 模型按需下载配置。
///
/// 模型文件 (中文 116MB / 英文 75MB) 已从 APK 中移除，改为首次使用时
/// 从远程按需下载。下载顺序：本地缓存 → 远程直链 → 回退 assets 打包文件。
///
/// 远程直链走 Cloudflare R2 (免费 10GB 存储 + 无单文件 50M 限制)，
/// 直链格式：`https://<账户ID>.r2.dev/tts_model/zh/vits-zh-hf-fanchen-C.onnx`。
///
/// TODO(xppobnome): 替换为真实 R2 公共域名后，删掉这段 TODO。
class TtsModelStore {
  TtsModelStore._();

  /// R2 直链根地址 (末尾不含斜杠)。
  ///
  /// 桶 `hero-adventure` 已绑定自定义域名 `tts.cloudvl.de5.net` (走 Cloudflare
  /// CDN 边缘缓存，国内访问比裸 r2.dev 更快)。桶根目录下直接是 `tts_model/`
  /// 目录，故此处只填域名本身，不含桶名。
  /// 最终下载地址形如：
  ///   `https://tts.cloudvl.de5.net/tts_model/zh/vits-zh-hf-fanchen-C.onnx`
  ///
  /// 备用直链 (r2.dev 公共域名，国内较慢)：
  ///   `https://pub-20b1ee8e3ad1449b8c69f85aa093e36f.r2.dev`
  static const String _remoteBase = 'https://tts.cloudvl.de5.net';

  /// 相对路径 → (远程相对路径, 本地 assets 路径)。
  ///
  /// 远程路径与 assets 路径保持同一相对结构，便于统一处理。
  static const Map<String, String> _remoteByRel = <String, String>{
    // 中文模型
    'zh/vits-zh-hf-fanchen-C.onnx': 'zh/vits-zh-hf-fanchen-C.onnx',
    'zh/tokens.txt': 'zh/tokens.txt',
    'zh/lexicon.txt': 'zh/lexicon.txt',
    'zh/date.fst': 'zh/date.fst',
    'zh/number.fst': 'zh/number.fst',
    'zh/phone.fst': 'zh/phone.fst',
    'zh/new_heteronym.fst': 'zh/new_heteronym.fst',
    // 英文模型
    'en/en_US-libritts_r-medium.onnx': 'en/en_US-libritts_r-medium.onnx',
    'en/tokens.txt': 'en/tokens.txt',
  };

  /// 模型相对路径列表 (assets 路径去掉 `assets/tts_model/` 前缀)。
  static const List<String> rels = <String>[
    'zh/vits-zh-hf-fanchen-C.onnx',
    'zh/tokens.txt',
    'zh/lexicon.txt',
    'zh/date.fst',
    'zh/number.fst',
    'zh/phone.fst',
    'zh/new_heteronym.fst',
    'en/en_US-libritts_r-medium.onnx',
    'en/tokens.txt',
  ];

  /// 计算远程直链地址。
  static String remoteUrl(String rel) => '$_remoteBase/tts_model/$rel';
}

/// 离线神经网络 TTS 服务 (Sherpa-ONNX 中文 VITS + 英文 Piper 双模型)。
///
/// 背景：系统 flutter_tts 对「单字中文」「单词英文」发音不稳定，
/// 曾两次接入离线方案 (讯飞 AIKit / Sherpa vits-melo 双语模型) 均失败。
/// 根因是 vits-melo 双语模型对超短文本合成不稳定。
///
/// 本服务采用**纯中文 + 纯英文分模型**方案 (已在本地用 Python 实测验证：
/// 孤立单字中文 / 单词英文均能稳定合成有效音频)：
/// - 中文 (拼音呼读音 / 识字汉字)：`vits-zh-hf-fanchen-C` (116MB，内置 jieba 分词)
/// - 英文 (单词跟读)：`vits-piper-en_US-libritts_r-medium` (75MB，需 espeak-ng 音素化)
///
/// 架构要点：
/// - 模型加载与合成放在独立 [Isolate] (Sherpa 的 generate 是同步阻塞 FFI，
///   放主 isolate 会卡 UI)。
/// - 英文 Piper 模型在 sherpa-onnx v2.0+ 需外部音素化，用 `piper_phonemize`
///   (内置 espeak-ng-data) 把文本转成 phoneme codepoints 后传入。
/// - 合成结果 PCM → 写 WAV → just_audio 播放。
/// - 任意环节失败 → 调用方降级到系统 flutter_tts。
class SherpaTtsService {
  static final SherpaTtsService instance = SherpaTtsService._();
  SherpaTtsService._();

  // ---- isolate 通信 ----
  Isolate? _isolate;
  SendPort? _port;
  ReceivePort? _receivePort;
  bool _initializing = false;
  bool _ready = false;

  /// 模型下载进度回调 (供界面显示「正在下载语音模型…」)。
  /// 参数：已完成字节数 / 总字节数 (总字节数可能为 0 表示未知)。
  void Function(int received, int total)? onModelDownloadProgress;

  /// 是否正在下载模型 (首次使用时，界面可据此提示用户等待)。
  bool _downloading = false;
  bool get isDownloading => _downloading;

  // ---- 请求序号 → 完成回调 ----
  int _seq = 0;
  final Map<int, Completer<String?>> _pending = <int, Completer<String?>>{};

  // ---- 合成结果缓存 (文本+学科 → WAV 路径) ----
  // 重复朗读同一条目直接复用，免去 isolate 重新合成，削峰首点击延迟。
  final Map<String, String> _cache = <String, String>{};

  // ---- 在途合成去重：同一 key 正在合成时，复用其 future ----
  // 解决「预热未完成时点击」或「预热与点击并发」导致的重复合成与延迟：
  // 点击读一遍时若同文本正在后台预合成，直接 await 同一个结果，而非新发一条请求。
  final Map<String, Completer<String?>> _inflight =
      <String, Completer<String?>>{};

  final Map<int, String> _pendingKey = <int, String>{};

  // ---- 后台预合成串行队列 ----
  // 关键：isolate 是单线程串行处理合成请求 (每个是同步阻塞 FFI)。
  // 若「预载全部条目」瞬间派发几十上百个请求，isolate 逐个合成、
  // 每个请求 15s 超时 → 队尾大面积超时。因此后台预合成改为 FIFO 串行：
  // 一次只派发一个请求，await 完成后再发下一个，保证 isolate 不积压。
  final List<_PrefetchTask> _prefetchQueue = <_PrefetchTask>[];
  bool _prefetchDraining = false;

  /// 已请求过预合成的 key 集合 (避免队列里重复堆积同一条目)。
  final Set<String> _prefetchQueued = <String>{};

  // ---- 播放器 (主 isolate) ----
  final AudioPlayer _player = AudioPlayer();

  /// 是否已就绪 (模型加载完成)。
  bool get isReady => _ready;

  /// 检测本地模型文件是否已就位 (只查磁盘，不触发下载)。
  ///
  /// 用于首次进入时判断「是否需要下载资源」：识字/英语跟读依赖离线 TTS
  /// 模型，模型未就位时应提示用户下载，而不是让用户进入后听不到声音。
  Future<bool> isModelReady() async {
    try {
      final base = await getApplicationSupportDirectory();
      final root = p.join(base.path, 'tts_model');
      // 关键模型文件 (中文 + 英文 onnx) 存在且非空即视为就绪。
      const critical = <String>[
        'zh/vits-zh-hf-fanchen-C.onnx',
        'en/en_US-libritts_r-medium.onnx',
      ];
      for (final rel in critical) {
        final f = File(p.join(root, rel));
        if (!await f.exists() || await f.length() <= 0) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[SherpaTts] 模型就绪检测失败: $e');
      return false;
    }
  }

  /// 惰性启动 isolate 并加载中英两个模型。
  ///
  /// 幂等：重复调用若已就绪立即返回；若正在初始化则等待其完成。
  ///
  /// 注意：首次初始化可能包含模型下载 (191MB)，耗时可达数分钟，
  /// 因此「等待初始化」不设硬超时，会一直等到就绪或明确失败。
  Future<bool> ensureReady() async {
    if (_ready) return true;
    if (_initializing) {
      // 等待初始化完成 (不设硬超时，覆盖首次模型下载的耗时)。
      while (!_ready && _initializing) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return _ready;
    }
    _initializing = true;
    try {
      // 先把模型文件就位到应用支持目录 (本地缓存 → 远程下载 → assets 回退)，
      // isolate 内无法直接访问 rootBundle，必须先把模型落盘。
      _downloading = true;
      final dir = await _ensureModelsOnDisk();
      _downloading = false;
      if (dir == null) {
        debugPrint('[SherpaTts] 模型文件就位失败');
        return false;
      }

      // 解包 espeak-ng-data (piper 音素化前端需要，主 isolate 才能访问 rootBundle)。
      String espeakDataDir = '';
      try {
        espeakDataDir = await piper.extractEspeakNgData();
        AppLogger.d('SherpaTts', 'espeak-ng-data 解包成功: $espeakDataDir');
      } catch (e) {
        AppLogger.e('SherpaTts', 'espeak-ng-data 解包失败 (英文音素化将不可用): $e');
      }

      // 临时目录 (isolate 内写 WAV 用)。
      final tmpDir = (await getTemporaryDirectory()).path;

      final receivePort = ReceivePort();
      _receivePort = receivePort;
      _isolate = await Isolate.spawn(
        _isolateMain,
        _IsolateInit(
          zhDir: p.join(dir, 'zh'),
          enDir: p.join(dir, 'en'),
          espeakDataDir: espeakDataDir,
          tmpDir: tmpDir,
          sendPort: receivePort.sendPort,
        ),
      );

      // 等待 isolate 回传 sendPort + ready 状态。
      final completer = Completer<bool>();
      receivePort.listen((msg) {
        if (msg is _IsolateReady) {
          _port = msg.sendPort;
          _ready = msg.ok;
          if (!completer.isCompleted) completer.complete(msg.ok);
        } else if (msg is _SynthResult) {
          final c = _pending.remove(msg.seq);
          final k = _pendingKey.remove(msg.seq);
          if (k != null) _inflight.remove(k); // 合成完成，清除在途标记
          if (k != null && msg.wavPath.isNotEmpty) _cache[k] = msg.wavPath;
          if (c != null && !c.isCompleted) c.complete(msg.wavPath);
        } else if (msg is _IsolateError) {
          AppLogger.e('SherpaTts', 'isolate 错误: ${msg.message}');
          if (!completer.isCompleted) completer.complete(false);
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[SherpaTts] 模型加载超时');
          return false;
        },
      );
    } catch (e) {
      debugPrint('[SherpaTts] 启动失败: $e');
      return false;
    } finally {
      _initializing = false;
      _downloading = false;
    }
  }

  /// 确保中英模型文件就位到应用支持目录，返回模型根目录路径。
  ///
  /// isolate 内无法访问 rootBundle，必须先把模型落盘。
  ///
  /// 就位顺序 (每文件独立判断)：
  /// 1. 本地缓存已存在且非空 → 直接复用 (跳过网络)；
  /// 2. 否则从远程直链下载 (Cloudflare R2)；
  /// 3. 下载失败 (无网络 / 直链未配置) → 回退 assets 复制 (兼容本地调试/旧包)。
  Future<String?> _ensureModelsOnDisk() async {
    try {
      final base = await getApplicationSupportDirectory();
      final root = p.join(base.path, 'tts_model');
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final client = http.Client();
      try {
        for (final rel in TtsModelStore.rels) {
          final target = p.join(root, rel);
          final f = File(target);

          // 1. 本地已就位 (非空) → 跳过。
          if (await _fileUsable(f)) continue;

          // 2. 远程下载。
          final url = TtsModelStore.remoteUrl(rel);
          final downloaded = await _download(client, url, target, label: rel);
          if (downloaded) continue;

          // 3. 回退 assets 复制。
          await _copyFromAssets(rel, target);
        }
      } finally {
        client.close();
      }
      return root;
    } catch (e) {
      debugPrint('[SherpaTts] 模型目录就位失败: $e');
      return null;
    }
  }

  /// 判断文件是否已就位且非空。
  Future<bool> _fileUsable(File f) async {
    try {
      return await f.exists() && await f.length() > 0;
    } catch (_) {
      return false;
    }
  }

  /// 从远程直链下载文件到 [target]，成功返回 true。
  Future<bool> _download(
    http.Client client,
    String url,
    String target, {
    required String label,
  }) async {
    try {
      debugPrint('[SherpaTts] 下载模型: $label');
      final resp = await client.send(http.Request('GET', Uri.parse(url)));

      if (resp.statusCode != 200) {
        debugPrint('[SherpaTts] 下载失败 (HTTP ${resp.statusCode}): $label');
        return false;
      }

      final f = File(target);
      await f.parent.create(recursive: true);
      final sink = f.openWrite();
      var received = 0;
      final total = resp.contentLength ?? 0;
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          // 上报进度 (节流：仅每 512KB 或完成时回调，避免高频刷新 UI)。
          if (chunk.length > 0 &&
              (received % (512 * 1024) < chunk.length || received >= total)) {
            onModelDownloadProgress?.call(received, total);
          }
        }
      } finally {
        await sink.close();
      }
      // 完成时确保最后一次进度到位。
      onModelDownloadProgress?.call(received, total);

      // 校验：下载后文件大小应 > 0；若服务端给了 content-length 则校验完整性。
      if (received <= 0) {
        debugPrint('[SherpaTts] 下载结果为空: $label');
        if (await f.exists()) await f.delete();
        return false;
      }
      if (total > 0 && received != total) {
        debugPrint('[SherpaTts] 下载不完整 ($received/$total): $label');
        if (await f.exists()) await f.delete();
        return false;
      }
      debugPrint('[SherpaTts] 下载完成 ($received bytes): $label');
      return true;
    } catch (e) {
      debugPrint('[SherpaTts] 下载异常: $label -> $e');
      return false;
    }
  }

  /// 从 assets 复制模型文件到磁盘 (旧包兼容 / 本地调试回退)。
  Future<void> _copyFromAssets(String rel, String target) async {
    final asset = 'assets/tts_model/$rel';
    try {
      final data = await rootBundle.load(asset);
      final f = File(target);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      debugPrint('[SherpaTts] 从 assets 复制: $rel');
    } catch (e) {
      // dict/ 目录文件 sherpa v2.0 起不再强制需要，缺失不阻断。
      debugPrint('[SherpaTts] 复制 $asset 失败(可忽略): $e');
    }
  }

  /// 朗读文本 (中文单字/英文单词)。
  ///
  /// [subject] 决定用哪个模型 (english → 英文模型，其余 → 中文模型)。
  /// [appendChinese] 可选：英文单词后的中文释义 (用中文模型再读一遍)。
  ///
  /// 返回是否成功 (失败时调用方应降级 flutter_tts)。
  Future<bool> speak(
    String text, {
    required String subject,
    String? appendChinese,
  }) async {
    final ok = await ensureReady();
    if (!ok || _port == null) {
      debugPrint('[SherpaTts] 未就绪，speak 失败');
      return false;
    }

    try {
      // 主段朗读。
      final mainOk = await _synthesizeAndPlay(text, subject: subject);
      if (!mainOk) return false;

      // 英文追加中文释义 (切中文模型)。
      if (appendChinese != null && appendChinese.isNotEmpty) {
        final zhOk = await _synthesizeAndPlay(
          appendChinese,
          subject: LearnSubjects.hanzi, // 中文模型
        );
        return zhOk;
      }
      return true;
    } catch (e) {
      debugPrint('[SherpaTts] 朗读失败: $e');
      return false;
    }
  }

  /// 合成缓存键：学科 + 文本。
  String _cacheKey(String text, String subject) => '$subject:::$text';

  /// 预合成并缓存某段文本 (不播放)。
  ///
  /// 进页面时预热当前条目：模型就绪后触发 isolate 合成并把 WAV 存入 [_cache]，
  /// 首次点击「听一遍」直接命中缓存，免去合成等待。
  ///
  /// 同 key 已在途/已缓存/已入队时直接跳过，避免重复派发。
  ///
  /// 注意：本方法走**串行预合成队列** (非立即派发)。isolate 单线程串行处理
  /// 合成请求，若瞬间派发海量请求会造成队尾超时，故后台预载逐个串行执行。
  Future<void> prefetch(String text, {required String subject}) async {
    final ok = await ensureReady();
    if (!ok || _port == null) return;
    final key = _cacheKey(text, subject);
    if (_cache.containsKey(key) ||
        _inflight.containsKey(key) ||
        _prefetchQueued.contains(key)) {
      return;
    }
    _prefetchQueued.add(key);
    _prefetchQueue.add(_PrefetchTask(text, subject));
    // 启动/继续串行排空队列。
    unawaited(_drainPrefetchQueue());
  }

  /// 预合成并**等待完成** (不播放)。
  ///
  /// 进页面首屏用：模型就绪后同步合成当前条目全部分段并落盘，
  /// 保证首次点击「听一遍」直接命中缓存、零等待发声。
  ///
  /// 本方法**直接派发** (不走后台队列)，保证首屏关键条目立即合成，
  /// 不受后台预载队列排队的延迟影响。
  Future<void> prefetchSync(String text, {required String subject}) async {
    final ok = await ensureReady();
    if (!ok || _port == null) return;
    final key = _cacheKey(text, subject);
    _prefetchQueued.add(key); // 标记已处理，避免后台队列再次重复合成
    await _requestSynth(text, subject: subject);
  }

  /// 串行排空预合成队列：一次只发一个请求，await 完成后再发下一个。
  Future<void> _drainPrefetchQueue() async {
    if (_prefetchDraining) return;
    _prefetchDraining = true;
    try {
      while (_prefetchQueue.isNotEmpty) {
        final task = _prefetchQueue.removeAt(0);
        final key = _cacheKey(task.text, task.subject);
        // 该 key 已出队，允许未来再次入队 (合成失败可重试)。
        _prefetchQueued.remove(key);
        // 已缓存/已在途则跳过本次 (直接派发下一个)。
        if (_cache.containsKey(key) || _inflight.containsKey(key)) continue;
        await _requestSynth(task.text, subject: task.subject);
      }
    } finally {
      _prefetchDraining = false;
    }
  }

  /// 合成一段文本并播放，返回是否成功。
  Future<bool> _synthesizeAndPlay(
    String text, {
    required String subject,
  }) async {
    final wavPath = await _requestSynth(text, subject: subject);
    if (wavPath == null) {
      AppLogger.w('SherpaTts', '合成失败或结果为空: "$text" (subject=$subject)');
      return false;
    }

    // 播放并等待完成。
    return await _playFile(wavPath);
  }

  /// 向 isolate 发送合成请求，等待返回 WAV 文件路径 (isolate 内完成写盘)。
  Future<String?> _requestSynth(String text, {required String subject}) async {
    final port = _port;
    if (port == null) return null;

    // 命中缓存：直接复用已合成 WAV (文件仍存在时)，避免重复合成。
    final key = _cacheKey(text, subject);
    final cached = _cache[key];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    // 同 key 正在合成中：复用在途 future，避免重复发请求造成延迟与竞态。
    // 典型场景：进页面预热与儿童点击「听一遍」并发，二者只触发一次真实合成。
    final inflight = _inflight[key];
    if (inflight != null) {
      return await inflight.future;
    }

    // 拼音声母纯辅音：用英文模型按 eSpeak 音素直接合成 (text 即音素串)。
    final isPhoneme = subject == LearnSubjects.phoneme;
    final isEnglish = subject == LearnSubjects.english || isPhoneme;
    final phonemeCodepoints = isPhoneme ? [text.runes.toList()] : null;

    // 发起新合成：登记在途标记，供并发请求复用。
    final completer = Completer<String?>();
    _inflight[key] = completer;
    final seq = ++_seq;
    _pendingKey[seq] = key;
    _pending[seq] = completer;

    port.send(
      _SynthRequest(
        seq: seq,
        text: text,
        isEnglish: isEnglish,
        phonemeCodepoints: phonemeCodepoints,
      ),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _inflight.remove(key);
          _pending.remove(seq);
          debugPrint('[SherpaTts] 合成超时: "$text"');
          return null;
        },
      );
    } catch (e) {
      _inflight.remove(key);
      _pending.remove(seq);
      debugPrint('[SherpaTts] 合成异常: $e');
      return null;
    }
  }

  /// 播放 WAV 文件并等待完成。
  Future<bool> _playFile(String path) async {
    try {
      await _player.stop();
      await _player.setFilePath(path);
      final completer = Completer<void>();
      final sub = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (!completer.isCompleted) completer.complete();
        }
      });
      await _player.play();
      // 兜底：按音频时长超时完成。
      final dur = _player.duration;
      if (dur != null && dur > Duration.zero) {
        Future.delayed(dur + const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) completer.complete();
        });
      }
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      sub.cancel();
      return true;
    } catch (e) {
      debugPrint('[SherpaTts] 播放失败: $e');
      return false;
    }
  }

  /// 立即停止播放。
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// 释放 isolate 与播放器 (应用退出时调用)。
  void dispose() {
    _pending.clear();
    _inflight.clear();
    _prefetchQueue.clear();
    _prefetchQueued.clear();
    _ready = false;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port = null;
    _receivePort?.close();
    _receivePort = null;
    try {
      _player.dispose();
    } catch (_) {}
  }
}

// ============================================================================
// isolate 内部消息对象 (同一 isolate group 内可直接传递)
// ============================================================================

class _IsolateInit {
  final String zhDir;
  final String enDir;
  final String espeakDataDir;
  final String tmpDir;
  final SendPort sendPort;
  _IsolateInit({
    required this.zhDir,
    required this.enDir,
    required this.espeakDataDir,
    required this.tmpDir,
    required this.sendPort,
  });
}

class _IsolateReady {
  final SendPort sendPort;
  final bool ok;
  _IsolateReady({required this.sendPort, required this.ok});
}

class _IsolateError {
  final String message;
  _IsolateError(this.message);
}

class _SynthRequest {
  final int seq;
  final String text;
  final bool isEnglish;
  final List<List<int>>? phonemeCodepoints;
  _SynthRequest({
    required this.seq,
    required this.text,
    required this.isEnglish,
    this.phonemeCodepoints,
  });
}

class _SynthResult {
  final int seq;
  final String wavPath; // 空串表示合成失败
  _SynthResult({required this.seq, required this.wavPath});
}

/// 后台预合成队列元素。
class _PrefetchTask {
  final String text;
  final String subject;
  _PrefetchTask(this.text, this.subject);
}

/// 输出增益：补偿 Sherpa 模型输出幅度偏低导致的「声音偏小」。
/// 可调参数：
/// - [_kNormalGain]   中文(拼音呼读音/识字)与英文单词；
/// - [_kPhonemeGain] 拼音声母纯辅音(单辅音能量低、时长短，需更强增益)。
const double _kNormalGain = 1.7;
const double _kPhonemeGain = 2.4;

/// 对 PCM 样本施加增益并限幅到 [-1,1]，避免削波破音。
Float32List _applyGain(Float32List samples, double gain) {
  final out = Float32List(samples.length);
  for (int i = 0; i < samples.length; i++) {
    final v = samples[i] * gain;
    out[i] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v);
  }
  return out;
}

// ============================================================================
// isolate 入口：加载模型 + 处理合成请求
// ============================================================================

/// isolate 主函数：初始化 sherpa + piper 绑定，加载中英两个模型，
/// 监听主 isolate 发来的合成请求，合成后写 WAV 并回传文件路径。
void _isolateMain(_IsolateInit init) async {
  final sendPort = init.sendPort;
  try {
    // 每个 isolate 都要初始化 FFI 绑定。
    await sherpa_onnx.initBindingsAsync();
    await piper.initBindingsAsync();

    // 中文模型 (拼音/识字)。
    final zh = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: p.join(init.zhDir, 'vits-zh-hf-fanchen-C.onnx'),
            lexicon: p.join(init.zhDir, 'lexicon.txt'),
            tokens: p.join(init.zhDir, 'tokens.txt'),
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: [
          p.join(init.zhDir, 'phone.fst'),
          p.join(init.zhDir, 'date.fst'),
          p.join(init.zhDir, 'number.fst'),
        ].join(','),
        maxNumSentences: 1,
      ),
    );

    // 英文模型 (单词跟读) + espeak-ng 音素化。
    final en = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: p.join(init.enDir, 'en_US-libritts_r-medium.onnx'),
            tokens: p.join(init.enDir, 'tokens.txt'),
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        maxNumSentences: 1,
      ),
    );

    // 初始化 piper 音素化 (用主 isolate 解包好的 espeak-ng-data 路径)。
    // 空路径时英文音素化不可用，但中文合成不受影响。
    if (init.espeakDataDir.isNotEmpty) {
      piper.PiperPhonemize.initialize(init.espeakDataDir);
    }

    // 回传 ready。
    final replyPort = ReceivePort();
    sendPort.send(_IsolateReady(sendPort: replyPort.sendPort, ok: true));

    // 监听合成请求。
    await for (final msg in replyPort) {
      if (msg is _SynthRequest) {
        String wavPath = '';
        try {
          final audio = _synthesize(
            zh: zh,
            en: en,
            text: msg.text,
            isEnglish: msg.isEnglish,
            phonemeCodepoints: msg.phonemeCodepoints,
          );
          if (audio.samples.isNotEmpty && audio.sampleRate > 0) {
            // 增益补偿：拼音/英文单词用 _kNormalGain，拼音声母纯辅音用 _kPhonemeGain。
            // 用户反馈两类发音都偏轻，统一限幅防削波。
            final gain = msg.phonemeCodepoints != null
                ? _kPhonemeGain
                : _kNormalGain;
            final samples = _applyGain(audio.samples, gain);
            // 在 isolate 内写 WAV (bindings 已就绪)。
            wavPath = p.join(
              init.tmpDir,
              'tts_${msg.seq}_${DateTime.now().microsecondsSinceEpoch}.wav',
            );
            sherpa_onnx.writeWave(
              filename: wavPath,
              samples: samples,
              sampleRate: audio.sampleRate,
            );
          }
        } catch (e) {
          AppLogger.e('SherpaTts.isolate', '合成异常: $e');
        }
        sendPort.send(_SynthResult(seq: msg.seq, wavPath: wavPath));
      }
    }
  } catch (e) {
    AppLogger.e('SherpaTts.isolate', '初始化失败: $e');
    sendPort.send(_IsolateError('$e'));
  }
}

/// 在 isolate 内执行合成，返回 PCM 音频。
sherpa_onnx.GeneratedAudio _synthesize({
  required sherpa_onnx.OfflineTts zh,
  required sherpa_onnx.OfflineTts en,
  required String text,
  required bool isEnglish,
  List<List<int>>? phonemeCodepoints,
}) {
  if (isEnglish) {
    if (phonemeCodepoints != null) {
      // 拼音声母纯辅音：直接使用传入的 eSpeak 音素串合成 (不依赖 phonemize)。
      AppLogger.d('SherpaTts', '英文合成(纯辅音音素): "$text"');
      final gen = sherpa_onnx.OfflineTtsGenerationConfig(
        sid: 0,
        speed: 1.0,
        silenceScale: 0.3,
        phonemeCodepoints: phonemeCodepoints,
      );
      final audio = en.generateWithConfig(text: '', config: gen);
      AppLogger.d(
        'SherpaTts',
        '英文纯辅音合成结果: samples=${audio.samples.length} sr=${audio.sampleRate}',
      );
      return audio;
    }
    // 英文单词：先 espeak-ng 音素化，再传 phonemeCodepoints。
    List<List<int>> sentences;
    try {
      sentences = piper.PiperPhonemize.phonemize(
        text,
        voice: 'en-us',
      ).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      AppLogger.e('SherpaTts', '英文音素化异常: "$text" -> $e');
      return sherpa_onnx.GeneratedAudio(samples: Float32List(0), sampleRate: 0);
    }
    if (sentences.isEmpty) {
      // 音素化失败，返回空。
      AppLogger.w('SherpaTts', '英文音素化结果为空: "$text"');
      return sherpa_onnx.GeneratedAudio(samples: Float32List(0), sampleRate: 0);
    }
    AppLogger.d('SherpaTts', '英文音素化成功: "$text" -> $sentences');
    final gen = sherpa_onnx.OfflineTtsGenerationConfig(
      sid: 0,
      speed: 1.0,
      silenceScale: 0.3,
      phonemeCodepoints: sentences,
    );
    final audio = en.generateWithConfig(text: '', config: gen);
    AppLogger.d(
      'SherpaTts',
      '英文合成结果: samples=${audio.samples.length} sr=${audio.sampleRate}',
    );
    return audio;
  } else {
    // 中文：直接合成 (模型内置 jieba 分词)。
    return zh.generate(text: text, sid: 0, speed: 1.0);
  }
}
