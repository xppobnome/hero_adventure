import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/providers/family_provider.dart';
import '../../../domain/providers/theme_provider.dart';

import 'tabs/task_management_tab.dart';
import 'tabs/reward_management_tab.dart';
import 'tabs/approval_tab.dart';
import 'tabs/child_progress_tab.dart';
import 'tabs/settings_tab.dart';
import 'child_profile_management_view.dart';
import 'check_in_records_view.dart';
import 'approval_history_view.dart';

class ParentConsoleView extends ConsumerStatefulWidget {
  const ParentConsoleView({super.key});

  @override
  ConsumerState<ParentConsoleView> createState() => _ParentConsoleViewState();
}

class _ParentConsoleViewState extends ConsumerState<ParentConsoleView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    // 菜单栏文字标签是否展示（家长设置里可开关，实时响应）。
    final showLabels = ref.watch(showNavLabelsProvider);

    final tabs = [
      const ChildProgressTab(), // 儿童进度看板
      const TaskManagementTab(), // 任务 CRUD
      const ApprovalTab(), // 审批中心
      const RewardManagementTab(), // 奖励商城
      const SettingsTab(), // 系统设置
    ];

    const labels = ['进度', '任务', '审批', '奖励', '设置'];
    const icons = [
      Icons.dashboard,
      Icons.assignment,
      Icons.fact_check,
      Icons.store,
      Icons.settings,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('宇宙警备队总部', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
        actions: [
          // 历史记录入口（打卡记录 / 审批记录）用 PopupMenu 收纳，避免图标过多。
          PopupMenuButton<String>(
            icon: Icon(Icons.history, size: 22.r),
            tooltip: '记录中心',
            color: Colors.white,
            onSelected: (v) {
              if (v == 'checkin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckInRecordsView()),
                );
              } else if (v == 'approval') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApprovalHistoryView()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'checkin',
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: UltramanTheme.blue, size: 20.r),
                    SizedBox(width: 10.w),
                    Text('打卡记录', style: TextStyle(fontSize: 14.sp)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'approval',
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined, color: UltramanTheme.gold, size: 20.r),
                    SizedBox(width: 10.w),
                    Text('审批记录', style: TextStyle(fontSize: 14.sp)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.badge_outlined, size: 22.r),
            tooltip: '儿童档案管理',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChildProfileManagementView()),
              );
            },
          ),
        ],
      ),
      body: isTablet
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.grey.shade100,
                  selectedIndex: _currentIndex,
                  labelType: showLabels
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.none,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  destinations: [
                    for (int i = 0; i < tabs.length; i++)
                      NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: tabs[_currentIndex]),
              ],
            )
          : tabs[_currentIndex],
      bottomNavigationBar: isTablet
          ? null
          : SafeArea(
              top: false,
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                selectedItemColor: UltramanTheme.blue,
                showUnselectedLabels: showLabels,
                showSelectedLabels: showLabels,
                items: [
                  for (int i = 0; i < tabs.length; i++)
                    BottomNavigationBarItem(
                      icon: Icon(icons[i]),
                      label: showLabels ? labels[i] : '',
                    ),
                ],
              ),
            ),
    );
  }
}
