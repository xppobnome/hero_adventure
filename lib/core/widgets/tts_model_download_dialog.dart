import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/providers/theme_provider.dart';
import '../services/sherpa_tts_service.dart';
import 'ultraman_visuals.dart';

/// 语音资源下载对话框。
///
/// 首次进入识字 / 英语跟读时，若本地缺少离线 TTS 模型，弹出本对话框
/// 引导下载 (191MB 左右，仅需下载一次，之后永久缓存本地)。
///
/// 特性：
/// - 美化文案 + 实时进度条 + 下载速度/百分比展示；
/// - 下载完成后自动关闭并返回 true；失败/取消返回 false。
/// - 全程不可误触关闭 (barrierDismissible=false)，避免半成品状态。
Future<bool> showTtsModelDownloadDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TtsModelDownloadDialog(),
  ).then((v) => v ?? false);
}

class _TtsModelDownloadDialog extends StatefulWidget {
  const _TtsModelDownloadDialog();

  @override
  State<_TtsModelDownloadDialog> createState() =>
      _TtsModelDownloadDialogState();
}

class _TtsModelDownloadDialogState extends State<_TtsModelDownloadDialog> {
  // 下载进度：0.0 ~ 1.0 (未知总大小时用 -1 表示不确定进度)。
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _downloading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 监听下载进度回调。
    SherpaTtsService.instance.onModelDownloadProgress = (received, total) {
      if (!mounted) return;
      setState(() {
        _receivedBytes = received;
        _totalBytes = total;
        _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : -1.0;
      });
    };
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() => _downloading = true);
    final ok = await SherpaTtsService.instance.ensureReady();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _downloading = false;
        _done = true;
        _progress = 1.0;
      });
      // 短暂展示「就绪」后关闭。
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _downloading = false;
        _error = '语音资源下载失败，请检查网络后重试';
      });
    }
  }

  @override
  void dispose() {
    SherpaTtsService.instance.onModelDownloadProgress = null;
    super.dispose();
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final percent = _progress < 0
        ? null
        : (_progress * 100).clamp(0, 100).round();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标 + 标题
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: UltramanTheme.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.record_voice_over,
                color: UltramanTheme.blue,
                size: 34.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              _done ? '语音资源就绪啦' : '需要下载语音资源',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              _done
                  ? '马上为你打开学习大门'
                  : '识字和英语跟读需要语音发音，\n首次使用需下载约 190MB 的资源，\n请保持网络畅通，耐心等待片刻',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            SizedBox(height: 22.h),

            // 进度区
            if (_downloading || _done) ...[
              _buildProgressBar(percent),
              SizedBox(height: 12.h),
              Text(
                _done
                    ? '下载完成，正在准备发音引擎…'
                    : percent == null
                    ? '正在连接服务器，准备下载…'
                    : '正在下载 $percent%  ·  ${_fmtBytes(_receivedBytes)}'
                          '${_totalBytes > 0 ? ' / ${_fmtBytes(_totalBytes)}' : ''}',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
              ),
            ],
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.red.shade600),
                ),
              ),
            ],

            SizedBox(height: 20.h),
            // 按钮区
            if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('暂不下载'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UltramanTheme.blue,
                      ),
                      onPressed: _startDownload,
                      child: const Text('重新下载'),
                    ),
                  ),
                ],
              )
            else if (_done)
              Text(
                '准备完成，即将进入…',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
              )
            else
              Text(
                '下载中请勿退出，进度不会丢失',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int? percent) {
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: percent == null
            ? const _IndeterminateBar()
            : LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(UltramanTheme.blue),
              ),
      ),
    );
  }
}

/// 不确定进度条 (总大小未知时的滚动动画)。
class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar();

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.3,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(_ctrl.value * 300, 0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UltramanTheme.blue.withValues(alpha: 0.2),
                      UltramanTheme.blue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
