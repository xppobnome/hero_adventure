import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/learn_content/learn_item.dart';
import 'sherpa_tts_service.dart';

/// 语音能力统一封装：TTS 播放 + 语音识别，单例，供三个跟读模块复用。
///
/// 关键约束 (见架构 §7 共享知识)：
/// - `speech_to_text` 每应用会话只能 `initialize` 一次 → 用 [instance] 单例 + 懒初始化。
/// - 播放与识别共用音频通道 → 识别前必须先 [stopSpeaking]。
///
/// TTS 方案：优先离线 Sherpa-ONNX 神经网络 TTS (纯中文 VITS + 纯英文 Piper 双模型，
/// 已实测孤立单字中文 / 单词英文均稳定)，失败时降级系统 flutter_tts。
///
/// 备注：曾接入 Sherpa vits-melo 双语模型失败 (超短文本合成不稳定)，
/// 现改为纯中文 + 纯英文分模型方案，见 [SherpaTtsService]。
class SpeechService {
  static final SpeechService instance = SpeechService._();
  SpeechService._();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _sttInitialized = false;
  bool _sttInitializing = false;

  /// 当前活跃识别会话的完成回调 (配合 onStatus 'done' 兜底)。
  void Function(String?)? _activeCompleter;

  /// 探测指定学科的 TTS 语言是否可用 (英语缺失时用于界面提示)。
  ///
  /// 探测失败返回 true (不阻断，交给播放时兜底)，避免误报。
  Future<bool> isTtsLanguageAvailable(String subject) async {
    final lang = ttsLanguageOf(subject);
    try {
      final res = await _tts.isLanguageAvailable(lang);
      return res == true;
    } catch (_) {
      return true;
    }
  }

  /// 朗读文本 (按学科设置语言)，播放前先停止上次播放。
  ///
  /// 返回的 Future 在朗读完成后 resolve。
  ///
  /// 实现：优先离线 Sherpa TTS (中文 VITS / 英文 Piper 双模型，发音稳定)，
  /// 失败时降级系统 flutter_tts。
  /// [appendChinese] 可选：英语单词后追加的中文释义 (切换中文朗读)。
  ///
  /// 注意：拼音声母纯辅音 (subject=phoneme) 全程走 Sherpa，不降级系统 TTS——
  /// 系统 TTS 无法发孤立辅音 (如 f 会被读成字母名 "ef")，降级反而破坏发音内容。
  Future<void> speak(
    String text, {
    required String subject,
    String? appendChinese,
  }) async {
    // 拼音声母纯辅音：全程 Sherpa，不降级系统 TTS。
    if (subject == LearnSubjects.phoneme) {
      await SherpaTtsService.instance.speak(text, subject: subject);
      return;
    }

    // 优先 Sherpa 离线 TTS。
    final sherpaOk = await SherpaTtsService.instance.speak(
      text,
      subject: subject,
      appendChinese: appendChinese,
    );
    if (sherpaOk) return;

    // 降级系统 flutter_tts。
    debugPrint('[SpeechService] Sherpa 失败，降级系统 TTS');
    await _speakWithSystemTts(
      text,
      subject: subject,
      appendChinese: appendChinese,
    );
  }

  /// 预热离线 TTS 模型 (加载中英双模型)；进页面时调用以削峰首点击延迟。
  Future<bool> warmUp() => SherpaTtsService.instance.ensureReady();

  /// 检测本地 TTS 模型是否已就位 (不触发下载)。
  Future<bool> isModelReady() => SherpaTtsService.instance.isModelReady();

  /// 预合成指定文本并缓存 (不播放)；进页面/切题时预热当前条目。
  Future<void> prefetch(String text, {required String subject}) =>
      SherpaTtsService.instance.prefetch(text, subject: subject);

  /// 预合成并等待完成 (不播放)；进页面首屏用，保证首次点击零延迟。
  Future<void> prefetchSync(String text, {required String subject}) =>
      SherpaTtsService.instance.prefetchSync(text, subject: subject);

  /// 系统 flutter_tts 朗读。
  Future<void> _speakWithSystemTts(
    String text, {
    required String subject,
    String? appendChinese,
  }) async {
    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true);
      final lang = ttsLanguageOf(subject);
      await _tts.setLanguage(lang);
      // 儿童友好语速：中文/英文都放慢，便于跟读模仿。
      await _tts.setSpeechRate(0.4);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
      // 英语单词后追加中文释义 (切换 zh-CN 朗读)。
      if (appendChinese != null && appendChinese.isNotEmpty) {
        await _tts.awaitSpeakCompletion(true);
        await _tts.setLanguage('zh-CN');
        await _tts.speak(appendChinese);
      }
    } catch (e) {
      debugPrint('[SpeechService] TTS 播放失败: $e');
    }
  }

  /// 立即停止朗读。
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // 忽略停止失败
    }
    try {
      await SherpaTtsService.instance.stop();
    } catch (_) {
      // 忽略停止失败
    }
  }

  /// 初始化语音识别 (每应用会话只初始化一次)，返回是否可用/是否已授权。
  ///
  /// 通过 onStatus 监听 'done' 状态作为识别结束的兜底信号，
  /// 避免个别设备上 finalResult 迟迟不触发导致「读了一遍却没反应」。
  Future<bool> ensureRecognizer() async {
    if (_sttInitialized) return true;
    if (_sttInitializing) {
      // 正在初始化时等待其完成 (最多 3 秒)。
      for (int i = 0; i < 30 && !_sttInitialized; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _sttInitialized;
    }
    _sttInitializing = true;
    try {
      final ok = await _stt.initialize(
        onStatus: (status) {
          // 'done' 表示本次识别所有结果已交付，作为兜底完成信号。
          if (status == 'done') {
            final cb = _activeCompleter;
            if (cb != null) {
              _activeCompleter = null;
              cb(null);
            }
          }
        },
        onError: (err) {
          debugPrint('[SpeechService] 识别错误: ${err.errorMsg}');
        },
      );
      _sttInitialized = ok;
      return ok;
    } catch (e) {
      debugPrint('[SpeechService] 语音识别初始化失败: $e');
      _sttInitialized = false;
      return false;
    } finally {
      _sttInitializing = false;
    }
  }

  /// 开始识别，返回最终识别文本；失败/无结果/权限拒绝返回 null (视为「本次无效」)。
  ///
  /// [onPartial] 用于实时显示识别中的文字气泡。
  ///
  /// 稳健性设计：除依赖 onResult 的 finalResult 外，额外记录最后一次
  /// partial 文本，并在识别结束 (done 状态 / 超时) 时用它兜底判分，
  /// 避免个别设备 finalResult 迟迟不触发导致「读了一遍却没反应」。
  Future<String?> recognize({
    required String localeId,
    Duration listenFor = const Duration(seconds: 5),
    Duration pauseFor = const Duration(seconds: 2),
    void Function(String partial)? onPartial,
  }) async {
    final ok = await ensureRecognizer();
    if (!ok) {
      debugPrint('[SpeechService] 识别器不可用 (未初始化/权限拒绝)');
      return null;
    }

    // 识别前先停止朗读，避免录音抢占音频通道。
    await stopSpeaking();

    final completer = Completer<String?>();
    String lastPartial = '';

    // 完成本次识别 (供 onResult final / onStatus done / 超时 三路调用)。
    void finish(String? value) {
      if (completer.isCompleted) return;
      _activeCompleter = null;
      completer.complete(value);
    }

    _activeCompleter = (value) {
      // onStatus 'done' 兜底：若 final 迟迟未到，用最后的 partial 判分。
      finish(value ?? (lastPartial.isEmpty ? null : lastPartial));
    };

    try {
      await _stt.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) lastPartial = words;
          if (result.finalResult) {
            // final 结果：优先用最终文本。
            finish(words.isEmpty ? null : words);
          } else {
            onPartial?.call(words);
          }
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        cancelOnError: true,
        partialResults: true,
      );
      // 注意：listen() 启动后立即返回，识别结果通过 onResult/onStatus 异步交付。
    } catch (e) {
      debugPrint('[SpeechService] 语音识别失败: $e');
      finish(null);
    }

    // 硬超时兜底，避免底层异常导致 Future 悬挂。
    return completer.future.timeout(
      listenFor + const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('[SpeechService] 识别超时，用最后 partial 兜底: "$lastPartial"');
        if (lastPartial.isEmpty) return null;
        finish(null);
        return lastPartial;
      },
    );
  }

  /// 是否正在监听。
  bool get isListening => _stt.isListening;

  /// 停止监听 (保留已识别结果)。
  Future<void> stopRecognition() async {
    try {
      await _stt.stop();
    } catch (_) {
      // 忽略停止失败
    }
  }

  /// 取消监听 (丢弃已识别结果)。
  Future<void> cancelRecognition() async {
    _activeCompleter = null;
    try {
      await _stt.cancel();
    } catch (_) {
      // 忽略取消失败
    }
  }

  /// 释放插件资源 (应用退出时调用)。
  ///
  /// 注意：单例在页面 dispose 时不应调用本方法，否则会破坏后续模块复用；
  /// 页面退出时请改用 [stopSpeaking] / [cancelRecognition]。
  void dispose() {
    _activeCompleter = null;
    try {
      unawaited(_tts.stop());
    } catch (_) {}
    try {
      unawaited(_stt.cancel());
    } catch (_) {}
    _sttInitialized = false;
  }
}
