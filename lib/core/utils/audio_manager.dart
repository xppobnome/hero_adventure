import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../domain/hero_system.dart';

/// 音效管理器。
///
/// 采用双轨策略：
/// 1. 优先尝试用 just_audio 播放真实音频 (英雄专属音效优先，缺失回退通用)。
/// 2. 资源缺失时回退到系统提示音 + 震动反馈，保证打卡体验不断档。
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _sessionConfigured = false;

  /// 初始化音频会话 (Android 上播放音频必需，需在首次播放前调用一次)。
  ///
  /// 公开为可等待的方法，供 [main] 在应用启动时提前调用，
  /// 避免首次 setAsset 时因会话尚未就绪而静默失败。
  Future<void> ensureSession() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _sessionConfigured = true;
    } catch (_) {
      // 会话配置失败不阻断播放，交给 just_audio 默认处理
    }
  }

  /// 播放或回退音频，直到「播放结束」才完成。
  ///
  /// 返回的 Future 在音频自然播放完成 (或失败回退) 后 resolve，
  /// 调用方可据此在声音结束的同时执行后续动作 (如关闭弹窗)。
  Future<void> _playAsset(String assetPath) async {
    await ensureSession();
    try {
      // 先停止并清空上次状态，避免 setAsset 时状态污染导致播放失败
      await _player.stop();
      // 用明确的 AudioSource.asset 替代 setAsset，让 ExoPlayer 走 AssetDataSource
      await _player.setAudioSource(AudioSource.asset(assetPath));
      // 等待播放完成 (playerStateStream 的 completed 状态) 或异常
      await _playToCompletion();
    } catch (e) {
      // 记录真实错误，便于排查；随后回退到系统提示音 + 震动
      debugPrint('[AudioManager] 播放失败: $assetPath -> $e');
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    }
  }

  /// 开始播放并等待「播放完成」事件 (processingState == completed)。
  Future<void> _playToCompletion() async {
    final completer = Completer<void>();
    StreamSubscription<PlayerState>? sub;
    sub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    try {
      await _player.play();
      // 兜底：若音频极短 / 状态流未及时触发 completed，按时长超时完成
      final duration = _player.duration;
      if (duration != null && duration > Duration.zero) {
        Future.delayed(duration + const Duration(milliseconds: 200), () {
          if (!completer.isCompleted) {
            sub?.cancel();
            completer.complete();
          }
        });
      }
      await completer.future;
    } catch (e) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
      rethrow;
    }
  }

  /// 释放技能音效 (当前英雄专属音效优先，缺失回退通用)。
  ///
  /// 返回的 Future 在音效播放结束后 resolve，调用方可据此关闭弹窗。
  Future<void> playSkill(HeroEntry? hero) async {
    final asset = (hero != null && hero.skillSoundAsset.isNotEmpty)
        ? hero.skillSoundAsset
        : 'assets/audio/beam_attack.mp3';
    await _playAsset(asset);
  }

  // 光线攻击音效
  Future<void> playBeamAttack() async {
    await _playAsset('assets/audio/beam_attack.mp3');
  }

  // 启动音效 (开屏启动页播放)
  Future<void> playStartup() async {
    await _playAsset('assets/audio/启动音效.mp3');
  }

  // 胜利/升级音效
  Future<void> playVictory() async {
    await _playAsset('assets/audio/victory.mp3');
  }

  // 变身音效
  Future<void> playTransform() async {
    await _playAsset('assets/audio/transform.mp3');
  }

  /// 立即停止当前正在播放的音效。
  ///
  /// 供弹窗被手动关闭（如点击遮罩）时调用，确保声音与弹窗同步消失。
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      // 忽略停止失败
    }
  }

  // 报错/警报音效
  Future<void> playError() async {
    await ensureSession();
    try {
      await _player.stop();
      await _player.setAudioSource(AudioSource.asset('assets/audio/error.mp3'));
      await _player.play();
    } catch (e) {
      debugPrint('[AudioManager] 播放失败: error.mp3 -> $e');
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    }
  }

  void dispose() {
    _player.dispose();
  }
}
