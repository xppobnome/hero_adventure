import 'package:flutter/material.dart';

import '../../../data/learn_content/learn_display.dart';
import '../../../data/learn_content/learn_item.dart';
import '../../../domain/providers/theme_provider.dart';

/// 单条跟读的目标卡片 + 麦克风脉冲按钮。
///
/// [LearnTargetCard] 负责超大字号展示目标文本与辅助说明，并按状态描边
/// (对绿/错红/听金)；[PulsingMicButton] 为「我读一遍」按钮，录音时
/// 麦克风图标变红并带脉冲光圈动效，贴合儿童友好交互。

/// 目标卡片状态 (与 LearnQuizView 的条目状态机对应)。
enum LearnCardStatus { idle, playing, listening, recognizing, correct, wrong }

/// 超大字号目标卡片。
class LearnTargetCard extends StatelessWidget {
  final LearnItem item;
  final LearnCardStatus status;

  const LearnTargetCard({
    super.key,
    required this.item,
    this.status = LearnCardStatus.idle,
  });

  @override
  Widget build(BuildContext context) {
    final isEnglish = item.subject == LearnSubjects.english;
    // 拼音/汉字 ≥ 80px，英文 ≥ 64px (英文单词较长，避免溢出)。
    final displaySize = isEnglish ? 64.0 : 96.0;

    final (border, glow) = _decorFor(status);

    // 中文：例字/组词 (从 subText 解析)；英文：中文释义 (兼作「词语拼音」载体)。
    final word = LearnDisplay.secondaryWord(item);
    final pinyin = LearnDisplay.wordPinyin(item);
    final ipa = LearnDisplay.ipaOf(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 3),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: displaySize,
              fontWeight: FontWeight.bold,
              height: 1.1,
              color: const Color(0xFF1B2A6B),
            ),
          ),
          const SizedBox(height: 16),
          if (isEnglish)
            _buildEnglishSub(ipa: ipa)
          else if (word != null && pinyin.isNotEmpty)
            _WordWithPinyin(word: word, pinyin: pinyin)
          else if (item.subText.isNotEmpty)
            Text(
              item.subText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
        ],
      ),
    );
  }

  /// 英文辅助区：音标 + 中文释义 (释义上方标注拼音)。
  Widget _buildEnglishSub({required String? ipa}) {
    final meaning = item.subText;
    final pinyin = LearnDisplay.wordPinyin(item);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ipa != null && ipa.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '/$ipa/',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: UltramanTheme.blue,
                letterSpacing: 1,
              ),
            ),
          ),
        if (meaning.isNotEmpty) ...[
          if (pinyin.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                pinyin,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: UltramanTheme.blue,
                ),
              ),
            ),
          Text(
            meaning,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1B2A6B),
            ),
          ),
        ],
      ],
    );
  }

  (Color, Color) _decorFor(LearnCardStatus status) {
    switch (status) {
      case LearnCardStatus.correct:
        return (Colors.green, Colors.green);
      case LearnCardStatus.wrong:
        return (Colors.redAccent, Colors.redAccent);
      case LearnCardStatus.listening:
      case LearnCardStatus.recognizing:
        return (UltramanTheme.gold, UltramanTheme.gold);
      case LearnCardStatus.playing:
        return (UltramanTheme.blue, UltramanTheme.blue);
      case LearnCardStatus.idle:
      default:
        return (UltramanTheme.blue, UltramanTheme.blue);
    }
  }
}

/// 中文词/字 + 上方拼音 (满足「中文词语上面加拼音」)。
class _WordWithPinyin extends StatelessWidget {
  final String word;
  final String pinyin;
  const _WordWithPinyin({required this.word, required this.pinyin});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pinyin,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: UltramanTheme.blue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          word,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B2A6B),
          ),
        ),
      ],
    );
  }
}

/// 麦克风脉冲按钮 (「我读一遍」)。
class PulsingMicButton extends StatefulWidget {
  final bool active; // 是否正在录音/识别
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  const PulsingMicButton({
    super.key,
    required this.active,
    required this.onTap,
    this.enabled = true,
    this.label = '我读一遍',
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant PulsingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: widget.enabled ? widget.onTap : null,
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.active)
                Positioned(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(
                        alpha: (1 - _controller.value) * 0.55,
                      ),
                    ),
                    transform: Matrix4.identity()
                      ..scale(
                        1.0 + _controller.value * 0.9,
                        1.0 + _controller.value * 0.9,
                        1.0,
                      ),
                  ),
                ),
              Icon(
                Icons.mic,
                color: widget.active ? Colors.redAccent : Colors.white,
                size: 22,
              ),
            ],
          );
        },
      ),
      label: Text(
        widget.active ? '正在听...' : widget.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.active ? Colors.redAccent : UltramanTheme.blue,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
