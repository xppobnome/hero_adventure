import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:piper_phonemize/piper_phonemize.dart' as piper;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../data/learn_content/learn_item.dart';

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

  // ---- 请求序号 → 完成回调 ----
  int _seq = 0;
  final Map<int, Completer<String?>> _pending = <int, Completer<String?>>{};

  // ---- 合成结果缓存 (文本+学科 → WAV 路径) ----
  // 重复朗读同一条目直接复用，免去 isolate 重新合成，削峰首点击延迟。
  final Map<String, String> _cache = <String, String>{};

  // ---- 在途合成去重：同一 key 正在合成时，复用其 future ----
  // 解决「预热未完成时点击」或「预热与点击并发」导致的重复合成与延迟：
  // 点击读一遍时若同文本正在后台预合成，直接 await 同一个结果，而非新发一条请求。
  final Map<String, Completer<String?>> _inflight = <String, Completer<String?>>{};

  final Map<int, String> _pendingKey = <int, String>{};

  // ---- 播放器 (主 isolate) ----
  final AudioPlayer _player = AudioPlayer();

  /// 是否已就绪 (模型加载完成)。
  bool get isReady => _ready;

  /// 惰性启动 isolate 并加载中英两个模型。
  ///
  /// 幂等：重复调用若已就绪立即返回；若正在初始化则等待其完成。
  Future<bool> ensureReady() async {
    if (_ready) return true;
    if (_initializing) {
      // 等待初始化完成 (最多 15 秒，模型加载较慢)。
      for (int i = 0; i < 150 && !_ready; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _ready;
    }
    _initializing = true;
    try {
      // 先把模型文件从 assets 复制到应用支持目录 (isolate 内无法直接访问 rootBundle)。
      final dir = await _copyModelsToDisk();
      if (dir == null) {
        debugPrint('[SherpaTts] 模型文件复制失败');
        return false;
      }

      // 解包 espeak-ng-data (piper 音素化前端需要，主 isolate 才能访问 rootBundle)。
      String espeakDataDir = '';
      try {
        espeakDataDir = await piper.extractEspeakNgData();
      } catch (e) {
        debugPrint('[SherpaTts] espeak-ng-data 解包失败 (英文音素化将不可用): $e');
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
          debugPrint('[SherpaTts] isolate 错误: ${msg.message}');
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
    }
  }

  /// 把中英模型文件从 assets 复制到应用支持目录，返回模型根目录路径。
  ///
  /// isolate 内无法访问 rootBundle，必须先把模型落盘。
  Future<String?> _copyModelsToDisk() async {
    try {
      final base = await getApplicationSupportDirectory();
      final root = p.join(base.path, 'tts_model');
      final dir = Directory(root);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      const files = <String>[
        // 中文模型 (sherpa v2.0 起无需 dict 分词目录，省略以节省体积)
        'assets/tts_model/zh/vits-zh-hf-fanchen-C.onnx',
        'assets/tts_model/zh/tokens.txt',
        'assets/tts_model/zh/lexicon.txt',
        'assets/tts_model/zh/date.fst',
        'assets/tts_model/zh/number.fst',
        'assets/tts_model/zh/phone.fst',
        'assets/tts_model/zh/new_heteronym.fst',
        // 英文模型
        'assets/tts_model/en/en_US-libritts_r-medium.onnx',
        'assets/tts_model/en/tokens.txt',
      ];

      for (final asset in files) {
        final rel = asset.replaceFirst('assets/tts_model/', '');
        final target = p.join(root, rel);
        final f = File(target);
        if (await f.exists()) continue; // 已复制跳过
        try {
          final data = await rootBundle.load(asset);
          await f.create(recursive: true);
          await f.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } catch (e) {
          // dict/ 目录文件 sherpa v2.0 起不再强制需要，缺失不阻断。
          debugPrint('[SherpaTts] 复制 $asset 失败(可忽略): $e');
        }
      }
      return root;
    } catch (e) {
      debugPrint('[SherpaTts] 复制模型目录失败: $e');
      return null;
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
      final mainOk = await _synthesizeAndPlay(
        text,
        subject: subject,
      );
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
  /// 同 key 已在途/已缓存时直接跳过，避免重复派发。
  Future<void> prefetch(String text, {required String subject}) async {
    final ok = await ensureReady();
    if (!ok || _port == null) return;
    final key = _cacheKey(text, subject);
    if (_cache.containsKey(key) || _inflight.containsKey(key)) return;
    unawaited(_requestSynth(text, subject: subject));
  }

  /// 预合成并**等待完成** (不播放)。
  ///
  /// 进页面首屏用：模型就绪后同步合成当前条目全部分段并落盘，
  /// 保证首次点击「听一遍」直接命中缓存、零等待发声。
  Future<void> prefetchSync(String text, {required String subject}) async {
    final ok = await ensureReady();
    if (!ok || _port == null) return;
    await _requestSynth(text, subject: subject);
  }

  /// 合成一段文本并播放，返回是否成功。
  Future<bool> _synthesizeAndPlay(
    String text, {
    required String subject,
  }) async {
    final wavPath = await _requestSynth(text, subject: subject);
    if (wavPath == null) {
      debugPrint('[SherpaTts] 合成失败或结果为空: "$text"');
      return false;
    }

    // 播放并等待完成。
    return await _playFile(wavPath);
  }

  /// 向 isolate 发送合成请求，等待返回 WAV 文件路径 (isolate 内完成写盘)。
  Future<String?> _requestSynth(
    String text, {
    required String subject,
  }) async {
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

    // 发起新合成：登记在途标记，供并发请求复用。
    final completer = Completer<String?>();
    _inflight[key] = completer;
    final seq = ++_seq;
    _pendingKey[seq] = key;
    _pending[seq] = completer;

    port.send(_SynthRequest(
      seq: seq,
      text: text,
      isEnglish: subject == LearnSubjects.english,
    ));

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
  _SynthRequest({
    required this.seq,
    required this.text,
    required this.isEnglish,
  });
}

class _SynthResult {
  final int seq;
  final String wavPath; // 空串表示合成失败
  _SynthResult({required this.seq, required this.wavPath});
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
          );
          if (audio.samples.isNotEmpty && audio.sampleRate > 0) {
            // 在 isolate 内写 WAV (bindings 已就绪)。
            wavPath = p.join(
              init.tmpDir,
              'tts_${msg.seq}_${DateTime.now().microsecondsSinceEpoch}.wav',
            );
            sherpa_onnx.writeWave(
              filename: wavPath,
              samples: audio.samples,
              sampleRate: audio.sampleRate,
            );
          }
        } catch (e) {
          debugPrint('[SherpaTts.isolate] 合成异常: $e');
        }
        sendPort.send(_SynthResult(seq: msg.seq, wavPath: wavPath));
      }
    }
  } catch (e) {
    debugPrint('[SherpaTts.isolate] 初始化失败: $e');
    sendPort.send(_IsolateError('$e'));
  }
}

/// 在 isolate 内执行合成，返回 PCM 音频。
sherpa_onnx.GeneratedAudio _synthesize({
  required sherpa_onnx.OfflineTts zh,
  required sherpa_onnx.OfflineTts en,
  required String text,
  required bool isEnglish,
}) {
  if (isEnglish) {
    // 英文：先 espeak-ng 音素化，再传 phonemeCodepoints。
    final sentences = piper.PiperPhonemize.phonemize(text, voice: 'en-us')
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      // 音素化失败，返回空。
      return sherpa_onnx.GeneratedAudio(
        samples: Float32List(0),
        sampleRate: 0,
      );
    }
    final gen = sherpa_onnx.OfflineTtsGenerationConfig(
      sid: 0,
      speed: 1.0,
      silenceScale: 0.3,
      phonemeCodepoints: sentences,
    );
    return en.generateWithConfig(text: '', config: gen);
  } else {
    // 中文：直接合成 (模型内置 jieba 分词)。
    return zh.generate(text: text, sid: 0, speed: 1.0);
  }
}
