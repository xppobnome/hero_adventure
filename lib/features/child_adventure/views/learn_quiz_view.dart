import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/speech_service.dart';
import '../../../core/utils/audio_manager.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../data/learn_content/learn_display.dart';
import '../../../data/learn_content/learn_item.dart';
import '../../../data/models/task.dart';
import '../../../domain/check_in_logic.dart';
import '../../../domain/learn_quiz.dart';
import '../../../domain/providers/check_in_provider.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../widgets/learn_target_card.dart';

/// 儿童端统一跟读闯关界面 (学拼音 / 识字 / 学英语三个模块共用)。
///
/// 通过 [Task.learnSubject] 切换数据源、图标与 TTS 语言，
/// 复用「听一遍 → 下一题 → 全部听完发奖」闭环。
///
/// 说明：已移除语音自动判分与「我读一遍」按钮，
/// 儿童只需点「听一遍」听发音、点「下一题」切换，
/// 全部条目听完即发奖 (不判正确率)。
class LearnQuizView extends ConsumerStatefulWidget {
  final String childId;
  final Task task;
  const LearnQuizView({super.key, required this.childId, required this.task});

  @override
  ConsumerState<LearnQuizView> createState() => _LearnQuizViewState();
}

class _LearnQuizViewState extends ConsumerState<LearnQuizView> {
  late List<LearnItem> _items;
  late List<LearnCardStatus> _statuses;
  int _currentIndex = 0;
  bool _finished = false;
  bool _showRewardAnim = false;
  bool _rewardGranted = false;
  bool _englishTtsMissing = false;
  bool _preloaded = false;

  @override
  void initState() {
    super.initState();
    _generateItems();
    _checkEnglishTts();
    // 预热 TTS 模型：先 await 当前条目合成完成 (首点击零延迟)，再后台预载全部条目，
    // 彻底消除「听一遍」延迟。
    unawaited(SpeechService.instance.warmUp().then((ok) async {
      if (!ok || !mounted) return;
      await _prefetchCurrent(includeNext: true, wait: true);
      if (mounted) setState(() => _preloaded = true);
      unawaited(_prefetchAll()); // 后台预载剩余全部条目
    }));
  }

  /// 预合成朗读分段 (不播放)，进页面/切题时调用。
  ///
  /// [includeNext] 同时预取下一题，扩大缓存命中率，使「下一题」后点击也能即时发声。
  /// [wait] 为 true 时等待当前条目全部分段合成完成 (首屏用，保证首次点击零延迟)；
  /// 为 false 时后台派发，配合在途去重避免并发重复合成。
  Future<void> _prefetchCurrent({bool includeNext = true, bool wait = false}) async {
    if (_items.isEmpty) return;
    Future<void> prefetchItem(int idx) async {
      for (final seg in LearnDisplay.speakSegments(_items[idx])) {
        if (wait) {
          await SpeechService.instance.prefetchSync(seg.$1, subject: seg.$2);
        } else {
          SpeechService.instance.prefetch(seg.$1, subject: seg.$2);
        }
      }
    }

    await prefetchItem(_currentIndex);
    if (includeNext && _currentIndex < _items.length - 1) {
      unawaited(prefetchItem(_currentIndex + 1));
    }
  }

  /// 后台预载当前任务**全部**条目 (所有朗读分段)，点击任意条目均直接命中缓存。
  Future<void> _prefetchAll() async {
    if (_items.isEmpty) return;
    for (final item in _items) {
      for (final seg in LearnDisplay.speakSegments(item)) {
        SpeechService.instance.prefetch(seg.$1, subject: seg.$2);
      }
    }
  }

  @override
  void dispose() {
    // 停止朗读，但不 dispose 单例 (供后续模块复用)。
    unawaited(SpeechService.instance.stopSpeaking());
    super.dispose();
  }

  /// 英语设备缺 TTS 音源时提示家长到系统设置安装。
  Future<void> _checkEnglishTts() async {
    if (widget.task.learnSubject != LearnSubjects.english) return;
    final available = await SpeechService.instance
        .isTtsLanguageAvailable(LearnSubjects.english);
    if (!mounted || available) return;
    setState(() => _englishTtsMissing = true);
  }

  /// 抽题并重置状态。
  void _generateItems() {
    _items = LearnQuizGenerator(
      subject: widget.task.learnSubject,
      scope: widget.task.learnScope,
      count: widget.task.learnCount,
      ordered: widget.task.learnOrdered,
    ).generate();
    _statuses = List.generate(_items.length, (_) => LearnCardStatus.idle);
    _currentIndex = 0;
    _finished = false;
    _showRewardAnim = false;
    _rewardGranted = false;
  }

  String get _today {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 该任务当天是否已完成打卡 (防止重复跟读重复领奖)。
  bool _isAlreadyCompleted() {
    final records = ref.read(checkInProvider);
    return CheckInLogic.isCompleted(
      task: widget.task,
      childId: widget.childId,
      date: _today,
      records: records,
    );
  }

  /// 点「听一遍」：软件朗读当前条目 (中文补读词语，英文补读中文释义)。
  Future<void> _speak() async {
    if (_finished || _items.isEmpty) return;
    // 捕获本次朗读对应的条目索引，播放结束后校验索引未变再恢复视觉，
    // 避免播放期间儿童点「下一题」导致新条目状态被误重置。
    final index = _currentIndex;
    setState(() => _statuses[index] = LearnCardStatus.playing);
    final item = _items[index];
    // 按学科拆成朗读分段：中文补读词语，英文补读中文释义。
    final segments = LearnDisplay.speakSegments(item);
    for (final seg in segments) {
      await SpeechService.instance.speak(seg.$1, subject: seg.$2);
      if (!mounted || _currentIndex != index) return;
    }
    if (!mounted || _currentIndex != index) return;
    // 播放结束恢复初始状态。
    setState(() => _statuses[index] = LearnCardStatus.idle);
  }

  /// 下一题：到末尾则结算。
  void _next() {
    if (_finished) return;
    if (_currentIndex < _items.length - 1) {
      setState(() => _currentIndex++);
      // 后台预取新题 + 下一题，配合在途去重保证点击即时发声。
      unawaited(_prefetchCurrent(includeNext: true, wait: false));
    } else {
      _finish();
    }
  }

  /// 结算：全部读完即发奖 (不判正确率)。
  Future<void> _finish() async {
    if (_finished) return;
    final alreadyCompleted = _isAlreadyCompleted();

    setState(() => _finished = true);

    if (!alreadyCompleted) {
      AudioManager().playVictory();
      setState(() {
        _showRewardAnim = true;
        _rewardGranted = true;
      });
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
    } else {
      // 今日已完成后再读完：仅练习，不重复发奖。
      AudioManager().playVictory();
      setState(() => _rewardGranted = false);
    }
  }

  /// 重做一遍：重新抽题。
  void _retry() {
    setState(_generateItems);
  }

  String get _title {
    switch (widget.task.learnSubject) {
      case LearnSubjects.pinyin:
        return '拼音闯关';
      case LearnSubjects.hanzi:
        return '识字闯关';
      case LearnSubjects.english:
        return '英语闯关';
      default:
        return '跟读闯关';
    }
  }

  String get _scopeLabel {
    // 拼音已移除声母/韵母/整体认读分类，改为「按顺序 / 随机」说明。
    return widget.task.learnOrdered ? '按顺序' : '随机';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 18)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: UltramanStarfield()),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 1080 : 720),
              child: isLandscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout(),
            ),
          ),
          if (_showRewardAnim)
            Positioned.fill(
              child: IgnorePointer(
                child: CelebrationEffect(
                  title: '太棒了！',
                  subtitle:
                      '获得 ${widget.task.rewardExp} EXP / ${widget.task.rewardCoins} 币',
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

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildCurrentCard(),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _finished ? _buildResultBar() : _buildControls(),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧：说明 + 目标卡片
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildCurrentCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右侧：操作按钮 / 结果栏
          Expanded(
            flex: 2,
            child: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  child: _finished ? _buildResultBar() : _buildControls(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_subjectIcon(), color: UltramanTheme.gold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${learnSubjectLabel(widget.task.learnSubject)} · $_scopeLabel · 共 ${_items.length} 项',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_englishTtsMissing) ...[
              const SizedBox(height: 8),
              Text(
                '当前设备缺少英文发音，请到系统设置安装英文语音包',
                style: TextStyle(
                  color: UltramanTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCard() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Text(
          '暂无跟读内容',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }
    final item = _items[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '第 ${_currentIndex + 1} / ${_items.length} 项',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        LearnTargetCard(item: item, status: _statuses[_currentIndex]),
      ],
    );
  }

  Widget _buildControls() {
    final canAct = !_finished && _items.isNotEmpty;
    final isPlaying = canAct && _statuses[_currentIndex] == LearnCardStatus.playing;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canAct ? _speak : null,
            icon: _SpeakerIcon(active: isPlaying, loading: !_preloaded),
            label: const Text('听一遍'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UltramanTheme.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canAct ? _next : null,
            icon: const Icon(Icons.skip_next, size: 22),
            label: const Text('下一题'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UltramanTheme.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBar() {
    final total = _items.length;
    final granted = _rewardGranted;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  granted
                      ? '太棒了！完成 $total 项跟读，获得奖励！'
                      : '完成 $total 项跟读！(今日已完成，练习不计奖励)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (granted) ...[
            const SizedBox(height: 4),
            Text(
              '获得 ${widget.task.rewardExp} EXP / ${widget.task.rewardCoins} 币',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '再来一遍',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _subjectIcon() {
    switch (widget.task.learnSubject) {
      case LearnSubjects.pinyin:
        return Icons.record_voice_over;
      case LearnSubjects.hanzi:
        return Icons.text_fields;
      case LearnSubjects.english:
        return Icons.abc;
      default:
        return Icons.school;
    }
  }
}

/// 「听一遍」喇叭图标动态组件。
///
/// - [active] 朗读中：喇叭右侧三条声波动画 (高度起伏)，提示正在发声；
/// - [loading] 预加载中 (模型预热 / 首条合成尚未完成)：喇叭整体脉冲缩放，
///   给出「正在准备」的视觉反馈，避免儿童误以为卡顿；
/// - 其余状态：静态喇叭图标。
class _SpeakerIcon extends StatefulWidget {
  final bool active;
  final bool loading;
  const _SpeakerIcon({this.active = false, this.loading = false});

  @override
  State<_SpeakerIcon> createState() => _SpeakerIconState();
}

class _SpeakerIconState extends State<_SpeakerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = UltramanTheme.gold;
    if (widget.loading) {
      return ScaleTransition(
        scale: Tween<double>(0.75, 1.12).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
        ),
        child: Icon(Icons.volume_up, size: 22, color: color),
      );
    }
    if (widget.active) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, size: 22, color: color),
          const SizedBox(width: 3),
          ...List.generate(3, (i) => _wave(i, color)),
        ],
      );
    }
    return Icon(Icons.volume_up, size: 22, color: color);
  }

  Widget _wave(int i, Color color) {
    final start = 0.15 + i * 0.22;
    final anim = Tween<double>(0.25, 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, start + 0.55, curve: Curves.easeInOut),
      ),
    );
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(left: 2),
        width: 2.5,
        height: 6 + 12 * anim.value,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
