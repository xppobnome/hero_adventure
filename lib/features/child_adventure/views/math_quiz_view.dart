import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/audio_manager.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../data/models/task.dart';
import '../../../domain/check_in_logic.dart';
import '../../../domain/math_quiz.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 儿童端数学题学习界面。
///
/// 展示每日数学题，儿童用自定义数字键盘 (银行密码式) 输入答案，
/// 提交后判定正确题数，达到答对阈值则发放奖励并展示奖励动画；
/// 未达标可「重做一遍」(题目刷新重头再来)。
class MathQuizView extends ConsumerStatefulWidget {
  final String childId;
  final Task task;
  const MathQuizView({super.key, required this.childId, required this.task});

  @override
  ConsumerState<MathQuizView> createState() => _MathQuizViewState();
}

class _MathQuizViewState extends ConsumerState<MathQuizView> {
  late List<MathQuestion> _questions;
  late List<String> _answers; // 每题的作答字符串 (空串表示未答)
  int _focusedIndex = 0; // 当前聚焦的题目索引 (数字键盘输入目标)
  bool _submitted = false;
  bool _isSubmitting = false;
  bool _showRewardAnim = false; // 达标后展示奖励动画
  bool _rewardGranted = false; // 本次提交是否实际发放了奖励 (已完成后再答题不发)

  // 题目列表滚动控制器：切换上/下一题时自动滚动到聚焦题。
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 生成题目并重置作答状态。
  void _generateQuestions() {
    _questions = MathQuizGenerator(
      range: widget.task.mathRange,
      op: widget.task.mathOp,
      count: widget.task.mathCount,
    ).generate();
    _answers = List.generate(_questions.length, (_) => '');
    _focusedIndex = 0;
    _submitted = false;
    _isSubmitting = false;
    _showRewardAnim = false;
    _rewardGranted = false;
  }

  /// 数字键盘按键处理。
  void _onKeyTap(String key) {
    if (_submitted) return;
    setState(() {
      final current = _answers[_focusedIndex];
      if (key == 'del') {
        // 删除最后一位
        if (current.isNotEmpty) {
          _answers[_focusedIndex] = current.substring(0, current.length - 1);
        }
      } else if (key == 'next') {
        // 跳到下一题
        if (_focusedIndex < _questions.length - 1) {
          _focusedIndex++;
        }
      } else if (key == 'prev') {
        // 跳到上一题
        if (_focusedIndex > 0) {
          _focusedIndex--;
        }
      } else {
        // 数字：限制长度 (最多 3 位，避免输入过长)
        if (current.length < 3) {
          _answers[_focusedIndex] = current + key;
        }
      }
    });
    // 切换题目后，滚动列表让聚焦题可见（绑定滑动）。
    if (key == 'next' || key == 'prev') {
      _scrollToFocus();
    }
  }

  /// 滚动题目列表，使当前聚焦题出现在可视区域（估算每张卡片高度）。
  void _scrollToFocus() {
    if (!_scrollController.hasClients) return;
    final itemHeight = 78.0; // 单张卡片大致高度
    final target = _focusedIndex * itemHeight;
    final viewport = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clamped = target.clamp(0.0, maxScroll);
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 计算正确题数。
  int _correctCount() {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      final val = int.tryParse(_answers[i]);
      if (val != null && val == _questions[i].answer) {
        correct++;
      }
    }
    return correct;
  }

  String get _today {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 该任务当天是否已完成打卡 (防止重复答题重复领奖)。
  bool _isAlreadyCompleted() {
    final records = ref.read(checkInProvider);
    return CheckInLogic.isCompleted(
      task: widget.task,
      childId: widget.childId,
      date: _today,
      records: records,
    );
  }

  /// 判定是否达标 (答对题数达到阈值百分比)。
  bool _isPassed(int correct) {
    final total = _questions.length;
    if (total == 0) return false;
    final passCount = (total * widget.task.mathPassPercent / 100).ceil();
    return correct >= passCount;
  }

  /// 提交答案。
  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final alreadyCompleted = _isAlreadyCompleted();
    final correct = _correctCount();
    final passed = _isPassed(correct);

    setState(() {
      _submitted = true;
      _isSubmitting = false;
    });

    if (passed && !alreadyCompleted) {
      // 首次达标：播放奖励动画 + 音效，发放奖励
      AudioManager().playVictory();
      setState(() {
        _showRewardAnim = true;
        _rewardGranted = true;
      });

      // 提交打卡记录并发放奖励
      await ref.read(checkInProvider.notifier).addCheckIn(
            childId: widget.childId,
            taskId: widget.task.id,
            requirePhoto: false,
            rewardCoins: widget.task.rewardCoins,
            rewardExp: widget.task.rewardExp,
          );
      if (mounted) {
        await ref.read(familyProfileProvider.notifier).updateChildExp(
              widget.childId,
              widget.task.rewardExp,
              widget.task.rewardCoins,
            );
      }
    } else if (passed && alreadyCompleted) {
      // 已完成后再答题达标：仅练习，不发放奖励
      AudioManager().playVictory();
      setState(() => _rewardGranted = false);
    } else {
      // 未达标：提示音，等待重做
      AudioManager().playError();
      setState(() => _rewardGranted = false);
    }
  }

  /// 重做一遍：刷新题目，重头再来。
  void _retry() {
    setState(_generateQuestions);
  }

  @override
  Widget build(BuildContext context) {
    final opLabel = widget.task.mathOp == 'add'
        ? '加法'
        : widget.task.mathOp == 'sub'
            ? '减法'
            : '加减混合';

    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数学闯关', style: TextStyle(fontSize: 18)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: UltramanStarfield()),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 1080 : 720),
              child: isLandscape
                  ? _buildLandscapeLayout(opLabel)
                  : _buildPortraitLayout(opLabel),
            ),
          ),
          // 奖励动画覆盖层 (居中庆祝动画)
          if (_showRewardAnim)
            Positioned.fill(
              child: IgnorePointer(
                child: CelebrationEffect(
                  title: '太棒了！',
                  subtitle: '获得 ${widget.task.rewardExp} EXP / ${widget.task.rewardCoins} 币',
                  onCompleted: () {
                    if (mounted) setState(() => _showRewardAnim = false);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 竖屏布局：说明 + 题目列表 + 底部键盘（原有纵向结构）。
  Widget _buildPortraitLayout(String opLabel) {
    return Column(
      children: [
        _buildHeader(opLabel),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _questions.length,
            itemBuilder: (context, index) => _buildQuestionCard(index),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _submitted ? _buildResultBar() : _buildNumpad(),
          ),
        ),
      ],
    );
  }

  /// 横屏布局：左侧题目列表，右侧数字键盘（充分利用横向空间，免滚动看全）。
  Widget _buildLandscapeLayout(String opLabel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧：说明 + 题目列表
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildHeader(opLabel),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _questions.length,
                    itemBuilder: (context, index) => _buildQuestionCard(index),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右侧：数字键盘 + 结果栏
          Expanded(
            flex: 2,
            child: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  child: _submitted ? _buildResultBar() : _buildNumpad(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部说明。
  Widget _buildHeader(String opLabel) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calculate, color: UltramanTheme.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.task.mathRange}以内$opLabel · 共 ${_questions.length} 题 · 答对 ${widget.task.mathPassPercent}% 得奖励',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单道题目卡片。
  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final userAnswer = _answers[index];
    final isFocused = index == _focusedIndex;

    // 提交后判定对错
    Color? borderColor;
    Widget? trailing;
    if (_submitted) {
      final val = int.tryParse(userAnswer);
      final isCorrect = val == q.answer;
      borderColor = isCorrect ? Colors.green : Colors.red;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
            size: 22,
          ),
          if (!isCorrect) ...[
            const SizedBox(width: 6),
            Text(
              '${q.answer}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? (isFocused ? UltramanTheme.gold : UltramanTheme.blue),
          width: borderColor != null ? 2 : (isFocused ? 3 : 2),
        ),
        boxShadow: isFocused && !_submitted
            ? [
                BoxShadow(
                  color: UltramanTheme.gold.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: () {
          if (!_submitted) {
            setState(() => _focusedIndex = index);
          }
        },
        child: Row(
          children: [
            // 题号
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isFocused && !_submitted ? UltramanTheme.gold : UltramanTheme.blue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 算式
            Text(
              q.text.replaceAll(' = ?', ' ='),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2A6B),
              ),
            ),
            const SizedBox(width: 12),
            // 答案显示区
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFocused && !_submitted
                        ? UltramanTheme.gold
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  userAnswer.isEmpty ? '?' : userAnswer,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: userAnswer.isEmpty
                        ? Colors.grey
                        : const Color(0xFF1B2A6B),
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// 自定义数字键盘 (银行密码式)。
  Widget _buildNumpad() {
    const keys2 = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'prev', '0', 'del',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上一题/下一题 + 提交
        Row(
          children: [
            Expanded(
              child: _numpadButton('上一题', () => _onKeyTap('prev')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numpadButton('下一题', () => _onKeyTap('next')),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UltramanTheme.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isSubmitting ? '提交中...' : '提交 · 发动光线',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 数字键 3x4 网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: keys2.length,
          itemBuilder: (context, index) {
            final key = keys2[index];
            if (key == 'prev') return _numpadButton('‹', () => _onKeyTap('prev'));
            if (key == 'del') return _numpadButton('⌫', () => _onKeyTap('del'));
            return _numpadButton(key, () => _onKeyTap(key));
          },
        ),
      ],
    );
  }

  Widget _numpadButton(String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 提交后的结果栏。
  Widget _buildResultBar() {
    final correct = _correctCount();
    final total = _questions.length;
    final passed = _isPassed(correct);
    final granted = _rewardGranted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: passed
            ? Colors.green.withValues(alpha: 0.9)
            : UltramanTheme.gold.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                passed
                    ? (granted
                        ? '太棒了！答对 $correct/$total 题，获得奖励！'
                        : '答对 $correct/$total 题！(今日已完成，练习不计奖励)')
                    : '答对 $correct/$total 题，还差一点！',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (passed && granted) ...[
            const SizedBox(height: 4),
            Text(
              '获得 ${widget.task.rewardExp} EXP / ${widget.task.rewardCoins} 币',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ] else if (!passed) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: UltramanTheme.gold,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                '重做一遍',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
