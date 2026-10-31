import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../domain/providers/theme_provider.dart';

/// 拼音跟读教学视频播放器 (资源内置，asset 方式加载，无需联网)。
///
/// - 加载完成后自动播放；点击画面 / 底部按钮可暂停、继续。
/// - 进度条支持拖拽 (allowScrubbing)，方便儿童/家长回看某个声母、韵母。
/// - [onFinished] 在视频**首次播放到结尾**时回调一次 (用于触发闯关发奖)。
class PinyinVideoPlayer extends StatefulWidget {
  final VoidCallback? onFinished;
  const PinyinVideoPlayer({super.key, this.onFinished});

  @override
  State<PinyinVideoPlayer> createState() => _PinyinVideoPlayerState();
}

class _PinyinVideoPlayerState extends State<PinyinVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _finishedFired = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/pinyin_read_along.mp4',
    )..initialize().then((_) {
        if (!mounted) return;
        // 加载完成自动播放 (用户需求：进入即播放视频)。
        _controller.play();
        setState(() => _initialized = true);
      }).catchError((e) {
        debugPrint('[PinyinVideo] 视频初始化失败: $e');
      });
    _controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (_controller.value.isCompleted && !_finishedFired) {
      _finishedFired = true;
      widget.onFinished?.call();
    }
  }

  void _toggle() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final color = UltramanTheme.gold;
    final playing = _controller.value.isPlaying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              // 暂停时叠一层半透明遮罩 + 播放/暂停大图标。
              if (!playing)
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    color: Colors.black38,
                    child: const Icon(
                      Icons.play_arrow,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          colors: VideoProgressColors(
            playedColor: color,
            bufferedColor: color.withValues(alpha: 0.4),
            backgroundColor: Colors.white24,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                color: color,
              ),
              onPressed: _toggle,
            ),
          ],
        ),
      ],
    );
  }
}
