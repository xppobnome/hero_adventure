import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/audio_manager.dart';
import '../../../core/widgets/hero_showcase_dialog.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../domain/hero_system.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';

/// 英雄图鉴库。
///
/// 根据儿童当前等级解锁历代奥特曼卡牌，
/// 显示已解锁 / 未解锁状态及「距离解锁还差多少级」；
/// 已解锁英雄可点选「出战」，选中者用于打卡时展示技能动画与音效。
class HeroGalleryView extends ConsumerStatefulWidget {
  final String childId;
  const HeroGalleryView({super.key, required this.childId});

  @override
  ConsumerState<HeroGalleryView> createState() => _HeroGalleryViewState();
}

class _HeroGalleryViewState extends ConsumerState<HeroGalleryView> {
  /// 是否正在展示英雄出战弹窗 (防止连点重复弹窗)。
  bool _showingHeroDialog = false;

  /// 弹窗是否仍处于打开状态。用于区分「音效自然结束关闭」与
  /// 「用户手动点弹窗外部提前关闭」，避免手动关闭后 _playAndClose
  /// 又去 pop 一次 (误弹图鉴页)。
  bool _dialogOpen = false;

  Future<void> _onSelectHero(HeroEntry hero) async {
    if (_showingHeroDialog) return;
    _showingHeroDialog = true;

    // 先保存出战英雄
    await ref
        .read(familyProfileProvider.notifier)
        .selectHero(widget.childId, hero.id);

    if (!mounted) {
      _showingHeroDialog = false;
      return;
    }

    // 立即弹出居中弹窗展示该英雄 (点击即显示，不等声音)
    _showHeroDialog(hero);

    // 同时播放专属音效；声音结束的同时关闭弹窗 (playSkill 在播放完成时 resolve)
    unawaited(_playAndClose(hero));
  }

  /// 未解锁英雄：点击后同样弹出展示弹窗 + 音效 + 特效，但文字为「未解锁」。
  Future<void> _onTapLockedHero(HeroEntry hero) async {
    if (_showingHeroDialog) return;
    _showingHeroDialog = true;

    if (!mounted) {
      _showingHeroDialog = false;
      return;
    }

    _showHeroDialog(hero, badgeText: '未解锁');
    unawaited(_playAndClose(hero));
  }

  Future<void> _playAndClose(HeroEntry hero) async {
    try {
      await AudioManager().playSkill(hero);
    } catch (_) {
      // 播放异常也兜底关闭
    }
    if (!mounted) return;
    _showingHeroDialog = false;
    // 只有当弹窗仍然打开 (音效自然结束时) 才关闭它。
    // 若用户已手动点外部提前关闭 (barrierDismissible)，_dialogOpen 已被置 false，
    // 此时不再 pop，避免误弹掉图鉴页。
    if (!_dialogOpen) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _showHeroDialog(HeroEntry hero, {String badgeText = '已出战！'}) {
    _dialogOpen = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '英雄展示',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return HeroShowcaseDialog(hero: hero, badgeText: badgeText);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 弹性缩放 + 淡入过渡
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: curved,
            child: child,
          ),
        );
      },
    ).then((_) {
      // 弹窗关闭 (含手动点遮罩) 时：置标志位 + 停音效，保证声音同步停止。
      _dialogOpen = false;
      _showingHeroDialog = false;
      // 手动点外部关闭时立即停止正在播放的技能音效。
      AudioManager().stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProfileProvider);
    final child = family?.children.firstWhere((c) => c.id == widget.childId);
    final level = child == null ? 1 : levelFromExp(child.exp);
    final currentHeroId = child?.currentHeroId ?? 'ace';
    // 平板宽屏时增加列数并限制内容最大宽度，避免卡片被拉伸过大
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('英雄图鉴', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: UltramanTheme.deepSpace,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: UltramanStarfield()),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: GridView.builder(
                padding: EdgeInsets.all(16.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.w,
                  childAspectRatio: 0.78,
                ),
                itemCount: heroCatalog.length,
                itemBuilder: (context, index) {
                  final hero = heroCatalog[index];
                  final unlocked = level >= hero.unlockLevel;
                  final diffLevel = hero.unlockLevel - level;
                  final isCurrent = hero.id == currentHeroId;
                  return _HeroCard(
                    hero: hero,
                    unlocked: unlocked,
                    diffLevel: diffLevel,
                    isCurrent: isCurrent,
                    onSelect: unlocked
                        ? () => _onSelectHero(hero)
                        : () => _onTapLockedHero(hero),
                  );
                },
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroEntry hero;
  final bool unlocked;
  final int diffLevel;
  final bool isCurrent;
  final VoidCallback? onSelect;

  const _HeroCard({
    required this.hero,
    required this.unlocked,
    required this.diffLevel,
    required this.isCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${hero.colorHex}', radix: 16));
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isCurrent
                ? UltramanTheme.gold
                : unlocked
                    ? color
                    : Colors.grey.shade400,
            width: isCurrent ? 3 : 2,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: UltramanTheme.gold.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: [
            Expanded(
              child: Opacity(
                opacity: unlocked ? 1.0 : 0.25,
                child: UltramanHeroAvatar(size: 80.w, hero: hero),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              hero.name,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: unlocked ? Colors.black : Colors.grey,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              hero.title,
              style: TextStyle(fontSize: 11.sp, color: color),
            ),
            SizedBox(height: 6.h),
            if (isCurrent)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: UltramanTheme.gold,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text('出战中', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
              )
            else if (unlocked)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text('点选出战', style: TextStyle(color: Colors.white, fontSize: 11.sp)),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '还差 $diffLevel 级解锁',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11.sp),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
