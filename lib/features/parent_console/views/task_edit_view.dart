import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/ultraman_visuals.dart';
import '../../../data/models/task.dart';
import '../../../domain/providers/task_provider.dart';
import '../../../domain/providers/theme_provider.dart';

class TaskEditView extends ConsumerStatefulWidget {
  final Task? taskToEdit;

  const TaskEditView({super.key, this.taskToEdit});

  @override
  ConsumerState<TaskEditView> createState() => _TaskEditViewState();
}

class _TaskEditViewState extends ConsumerState<TaskEditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _coinsController;
  late TextEditingController _expController;
  String _selectedType = 'daily';
  bool _requirePhoto = false;
  String _iconName = 'default_monster'; // 怪兽图标
  final List<int> _selectedDays = []; // 自定义日期的星期几
  bool _isMathTask = false; // 是否为每日数学题学习任务 (独立于周期类型)

  // 自定义打卡周期 (type == 'custom_range')
  DateTime? _rangeStart; // 起始日期
  DateTime? _rangeEnd; // 结束日期

  // 数学题任务配置
  int _mathRange = 10; // 数值范围上限 (预设 10/20/50，或自定义)
  String _mathOp = 'add'; // add / sub / mix
  int _mathCount = 10; // 每天题目数量 (预设 10/30/50，或自定义)
  int _mathPassPercent = 100; // 答对题数百分比阈值 (默认 100%)
  bool _isCustomRange = false; // 是否使用自定义数值范围
  bool _isCustomCount = false; // 是否使用自定义题目数量
  bool _isCustomPass = false; // 是否使用自定义答对阈值
  final TextEditingController _customRangeController = TextEditingController();
  final TextEditingController _mathCountController = TextEditingController();
  final TextEditingController _passPercentController = TextEditingController();

  static const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 可选怪兽图标清单（名称 + 中文标签）。
  static const List<(String, String)> _monsterIcons = [
    ('default_monster', '默认'),
    ('tooth_monster', '蛀牙'),
    ('mess_monster', '邋遢'),
    ('cloth_monster', '穿衣'),
    ('dish_monster', '碗碟'),
    ('bath_monster', '洗澡'),
    ('sleep_monster', '睡觉'),
    ('book_monster', '阅读'),
    ('write_monster', '写字'),
    ('abc_monster', '英语'),
    ('homework_monster', '作业'),
    ('math_monster', '数学'),
    ('run_monster', '跑步'),
    ('clean_monster', '家务'),
    ('polite_monster', '礼貌'),
    ('share_monster', '分享'),
    ('nature_monster', '自然'),
    ('desk_monster', '书桌'),
    ('family_monster', '亲子'),
  ];

  /// 常见预设范围。
  static const List<int> _presetRanges = [10, 20, 50];

  /// 常见预设题目数量。
  static const List<int> _presetCounts = [10, 30, 50];

  /// 常见预设答对阈值 (百分比)。
  static const List<int> _presetPassPercents = [60, 80, 100];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _coinsController = TextEditingController(text: widget.taskToEdit?.rewardCoins.toString() ?? '10');
    _expController = TextEditingController(text: widget.taskToEdit?.rewardExp.toString() ?? '50');
    if (widget.taskToEdit != null) {
      _selectedType = widget.taskToEdit!.type;
      _requirePhoto = widget.taskToEdit!.requirePhoto;
      _iconName = widget.taskToEdit!.iconName;
      _selectedDays.addAll(widget.taskToEdit!.selectedDays);
      _isMathTask = widget.taskToEdit!.isMathTask;
      _mathRange = widget.taskToEdit!.mathRange;
      _mathOp = widget.taskToEdit!.mathOp;
      _mathCount = widget.taskToEdit!.mathCount;
      _mathPassPercent = widget.taskToEdit!.mathPassPercent;
      // 自定义打卡周期
      _rangeStart = DateTime.tryParse(widget.taskToEdit!.rangeStart);
      _rangeEnd = DateTime.tryParse(widget.taskToEdit!.rangeEnd);
      // 若保存的 range 不在预设中，则视为自定义范围
      _isCustomRange = !_presetRanges.contains(_mathRange);
      _customRangeController.text = _mathRange.toString();
      // 若保存的 count 不在预设中，则视为自定义题目数量
      _isCustomCount = !_presetCounts.contains(_mathCount);
      _mathCountController.text = _mathCount.toString();
      // 若保存的 passPercent 不在预设中，则视为自定义阈值
      _isCustomPass = !_presetPassPercents.contains(_mathPassPercent);
      _passPercentController.text = _mathPassPercent.toString();
    } else {
      _mathCountController.text = '10';
      _passPercentController.text = '100';
    }
  }

  @override
  void dispose() {
    _customRangeController.dispose();
    _mathCountController.dispose();
    _passPercentController.dispose();
    super.dispose();
  }

  /// 格式化日期为 YYYY-MM-DD。
  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 选择日期 (起止)。
  Future<void> _pickRangeDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_rangeStart ?? now) : (_rangeEnd ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: isStart ? '选择起始日期' : '选择结束日期',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _rangeStart = picked;
        // 若起始晚于结束，自动调整结束
        if (_rangeEnd != null && _rangeEnd!.isBefore(picked)) {
          _rangeEnd = picked;
        }
      } else {
        _rangeEnd = picked;
        // 若结束早于起始，自动调整起始
        if (_rangeStart != null && picked.isBefore(_rangeStart!)) {
          _rangeStart = picked;
        }
      }
    });
  }

  /// 日期选择输入框 (只读，点击弹出日期选择器)。
  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date == null ? '点击选择' : _formatDate(date),
          style: TextStyle(
            fontSize: 14.sp,
            color: date == null ? Colors.grey.shade500 : Colors.black,
          ),
        ),
      ),
    );
  }

  /// 任务周期下拉菜单项（带图标 + 标题 + 副标题，美化展开后的内容）。
  ///
  /// [selected] 为 true 时返回「选中态」的简洁展示（仅图标 + 标题，用于
  /// selectedItemBuilder 里显示在输入框内），否则返回完整菜单项。
  List<DropdownMenuItem<String>> _cycleItems({bool selected = false}) {
    // 每个周期类型的 (value, 图标, 标题, 副标题)
    const data = <(String, IconData, String, String)>[
      ('daily', Icons.wb_sunny_outlined, '每天任务', '每日巡逻，天天打卡'),
      ('weekly', Icons.event_available, '每周任务', '每周特训，一周一次'),
      ('checkin_week', Icons.flag_outlined, '打卡一周', '连续打卡满一周'),
      ('checkin_month', Icons.calendar_month, '连续打卡30天', '坚持打卡 30 天'),
      ('custom_days', Icons.date_range, '打卡指定星期', '每周固定几天打卡'),
      ('custom_range', Icons.tune, '自定义打卡周期', '自定义起止日期'),
      ('once', Icons.bolt, '单次任务', '紧急委托，完成一次即可'),
    ];

    return data.map((e) {
      final (value, icon, title, subtitle) = e;
      return DropdownMenuItem<String>(
        value: value,
        child: selected
            ? Row(
                children: [
                  Icon(icon, size: 20.sp, color: const Color(0xFF00A0E9)),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A0E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(icon, size: 20.sp, color: const Color(0xFF00A0E9)),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );
    }).toList();
  }

  /// 怪兽图标选择器：网格展示所有可选怪兽，点选高亮。
  Widget _buildMonsterPicker() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1.1,
      ),
      itemCount: _monsterIcons.length,
      itemBuilder: (context, index) {
        final (name, label) = _monsterIcons[index];
        final selected = _iconName == name;
        return GestureDetector(
          onTap: () => setState(() => _iconName = name),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? UltramanTheme.blue.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: selected ? UltramanTheme.blue : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MonsterAvatar(iconName: name, size: 40),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: selected ? UltramanTheme.blue : Colors.grey.shade700,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      // 最终任务类型：数学题开关打开时固定为 math，否则用周期类型
      final finalType = _isMathTask ? 'math' : _selectedType;

      // 若为自定义范围，读取并校验输入值
      int finalRange = _mathRange;
      if (_isMathTask && _isCustomRange) {
        final custom = int.tryParse(_customRangeController.text.trim());
        if (custom == null || custom <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请输入有效的数值范围 (大于 0 的整数)', style: TextStyle(fontSize: 14.sp))),
          );
          return;
        }
        finalRange = custom;
      }

      // 读取并校验每天题目数量 (预设或自定义)
      int finalCount = _mathCount;
      if (_isMathTask) {
        final countVal = int.tryParse(_mathCountController.text.trim());
        if (countVal == null || countVal <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请输入有效的每天题目数量 (大于 0 的整数)', style: TextStyle(fontSize: 14.sp))),
          );
          return;
        }
        finalCount = countVal;
      }

      // 读取并校验答对题数阈值 (百分比 1~100)
      int finalPassPercent = _mathPassPercent;
      if (_isMathTask) {
        final passVal = int.tryParse(_passPercentController.text.trim());
        if (passVal == null || passVal < 1 || passVal > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请输入有效的答对阈值 (1~100 的整数)', style: TextStyle(fontSize: 14.sp))),
          );
          return;
        }
        finalPassPercent = passVal;
      }

      // 自定义打卡周期校验
      if (_selectedType == 'custom_range') {
        if (_rangeStart == null || _rangeEnd == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请选择打卡周期的起始和结束日期', style: TextStyle(fontSize: 14.sp))),
          );
          return;
        }
        if (_rangeEnd!.isBefore(_rangeStart!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('结束日期不能早于起始日期', style: TextStyle(fontSize: 14.sp))),
          );
          return;
        }
      }

      // 计算周期窗口 (rangeStart/rangeEnd)：
      // - custom_range：家长手动选起止日期
      // - checkin_week：从「今天」起连续 7 天
      // - checkin_month：从「今天」起连续 30 天
      // 编辑已有任务时，若已存窗口则沿用（避免每次编辑都重置窗口）。
      String finalRangeStart = '';
      String finalRangeEnd = '';
      if (_selectedType == 'custom_range') {
        finalRangeStart = _formatDate(_rangeStart);
        finalRangeEnd = _formatDate(_rangeEnd);
      } else if (_selectedType == 'checkin_week' || _selectedType == 'checkin_month') {
        final days = _selectedType == 'checkin_week' ? 7 : 30;
        final existingStart = widget.taskToEdit?.rangeStart ?? '';
        final existingEnd = widget.taskToEdit?.rangeEnd ?? '';
        if (existingStart.isNotEmpty && existingEnd.isNotEmpty) {
          finalRangeStart = existingStart;
          finalRangeEnd = existingEnd;
        } else {
          final now = DateTime.now();
          finalRangeStart = _formatDate(now);
          finalRangeEnd = _formatDate(now.add(Duration(days: days - 1)));
        }
      }

      final task = Task(
        id: widget.taskToEdit?.id ?? const Uuid().v4(),
        title: _titleController.text,
        iconName: _iconName,
        rewardCoins: int.parse(_coinsController.text),
        rewardExp: int.parse(_expController.text),
        type: finalType,
        requirePhoto: _requirePhoto,
        selectedDays: _selectedType == 'custom_days' ? _selectedDays : const [],
        rangeStart: finalRangeStart,
        rangeEnd: finalRangeEnd,
        mathRange: _isMathTask ? finalRange : 10,
        mathOp: _isMathTask ? _mathOp : 'add',
        mathCount: _isMathTask ? finalCount : 10,
        mathPassPercent: _isMathTask ? finalPassPercent : 100,
      );

      if (widget.taskToEdit == null) {
        ref.read(taskProvider.notifier).addTask(task);
      } else {
        ref.read(taskProvider.notifier).updateTask(task);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.taskToEdit == null ? '新任务已下达！' : '任务已更新', style: TextStyle(fontSize: 14.sp))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit == null ? '下达新防卫任务' : '编辑任务', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 600.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: '任务名称 (例：打败蛀牙怪兽)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    validator: (v) => v!.isEmpty ? '任务名称不能为空' : null,
                  ),
                  SizedBox(height: 20.h),
                  // 怪兽图标选择
                  Text('选择怪兽形象', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8.h),
                  _buildMonsterPicker(),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: '奖励经验值 (EXP)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextFormField(
                          controller: _coinsController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: '奖励能量币 (Coins)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFF00A0E9), size: 22),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    menuMaxHeight: 420.h,
                    style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade900, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: '任务周期',
                      labelStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                      filled: true,
                      fillColor: const Color(0xFFF5F8FC),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      prefixIcon: const Icon(Icons.event_repeat, color: Color(0xFF00A0E9), size: 22),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: const Color(0xFF00A0E9).withValues(alpha: 0.4), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFF00A0E9), width: 1.8),
                      ),
                    ),
                    items: _cycleItems(),
                    selectedItemBuilder: (context) => _cycleItems(
                      selected: true,
                    ).map((e) => e.child!).toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  SizedBox(height: 16.h),
                  // 每日数学题学习任务 (独立入口，与周期类型区分)
                  SwitchListTile(
                    title: Text('每日数学题 (学习闯关)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    subtitle: Text('每天做数学题，儿童作答后获得奖励', style: TextStyle(fontSize: 13.sp)),
                    value: _isMathTask,
                    activeColor: UltramanTheme.blue,
                    onChanged: (v) => setState(() {
                      _isMathTask = v;
                      // 打开数学题开关时，若奖励仍为默认值，则填入推荐预设
                      if (v && _expController.text == '50' && _coinsController.text == '10') {
                        _expController.text = '30';
                        _coinsController.text = '15';
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: 16.h),
                  // 数学题任务配置
                  if (_isMathTask) ...[
                    // 奖励说明 (发放币 + 经验，可修改)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: UltramanTheme.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: UltramanTheme.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.card_giftcard, color: UltramanTheme.blue, size: 18.r),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '奖励类型：发放 ${_expController.text} 经验 + ${_coinsController.text} 能量币（可修改上方奖励值）',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text('题目难度 (数值范围)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    // 预设范围 + 自定义
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.w,
                      children: [
                        for (final r in _presetRanges)
                          ChoiceChip(
                            label: Text('$r 以内'),
                            selected: !_isCustomRange && _mathRange == r,
                            selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                            onSelected: (_) => setState(() {
                              _isCustomRange = false;
                              _mathRange = r;
                            }),
                          ),
                        ChoiceChip(
                          label: const Text('自定义'),
                          selected: _isCustomRange,
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _isCustomRange = true),
                        ),
                      ],
                    ),
                    // 自定义范围输入框
                    if (_isCustomRange) ...[
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _customRangeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '自定义数值上限 (如 15、30、100)',
                          helperText: '结果与操作数均不超过该数值',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Text('运算类型', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: [
                        ChoiceChip(
                          label: const Text('加法'),
                          selected: _mathOp == 'add',
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _mathOp = 'add'),
                        ),
                        ChoiceChip(
                          label: const Text('减法'),
                          selected: _mathOp == 'sub',
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _mathOp = 'sub'),
                        ),
                        ChoiceChip(
                          label: const Text('加减混合'),
                          selected: _mathOp == 'mix',
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _mathOp = 'mix'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text('每天题目数量', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    // 预设数量 + 自定义
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.w,
                      children: [
                        for (final c in _presetCounts)
                          ChoiceChip(
                            label: Text('$c 题'),
                            selected: !_isCustomCount && _mathCount == c,
                            selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                            onSelected: (_) => setState(() {
                              _isCustomCount = false;
                              _mathCount = c;
                              _mathCountController.text = '$c';
                            }),
                          ),
                        ChoiceChip(
                          label: const Text('自定义'),
                          selected: _isCustomCount,
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _isCustomCount = true),
                        ),
                      ],
                    ),
                    // 自定义题目数量输入框
                    if (_isCustomCount) ...[
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _mathCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '自定义每天题目数量',
                          helperText: '大于 0 的整数',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                    SizedBox(height: 16.h),
                    Text('答对多少题获得奖励', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    // 预设阈值 + 自定义
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.w,
                      children: [
                        for (final p in _presetPassPercents)
                          ChoiceChip(
                            label: Text('$p%'),
                            selected: !_isCustomPass && _mathPassPercent == p,
                            selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                            onSelected: (_) => setState(() {
                              _isCustomPass = false;
                              _mathPassPercent = p;
                              _passPercentController.text = '$p';
                            }),
                          ),
                        ChoiceChip(
                          label: const Text('自定义'),
                          selected: _isCustomPass,
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _isCustomPass = true),
                        ),
                      ],
                    ),
                    // 自定义阈值输入框
                    if (_isCustomPass) ...[
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _passPercentController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '自定义答对百分比',
                          helperText: '1~100 的整数，如 75 表示答对 75% 即发奖励',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                    SizedBox(height: 16.h),
                  ],
                  // 自定义日期选择
                  if (_selectedType == 'custom_days') ...[
                    Text('选择需要打卡的日期', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final selected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(_weekdays[index]),
                          selected: selected,
                          selectedColor: UltramanTheme.blue.withValues(alpha: 0.3),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  // 自定义打卡周期 (起止日期)
                  if (_selectedType == 'custom_range') ...[
                    Text('选择打卡周期 (起止日期)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text(
                      '从起始日期到结束日期，期间每天均可打卡',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            label: '起始日期',
                            date: _rangeStart,
                            onTap: () => _pickRangeDate(isStart: true),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text('至', style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700)),
                        ),
                        Expanded(
                          child: _dateField(
                            label: '结束日期',
                            date: _rangeEnd,
                            onTap: () => _pickRangeDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                  ],
                  SwitchListTile(
                    title: Text('强制要求拍照凭证', style: TextStyle(fontSize: 16.sp)),
                    subtitle: Text('需家长在控制台审核后才发放奖励', style: TextStyle(fontSize: 14.sp)),
                    value: _requirePhoto,
                    onChanged: (v) => setState(() => _requirePhoto = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: 40.h),
                  ElevatedButton(
                    onPressed: _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text('保存任务', style: TextStyle(fontSize: 18.sp, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
