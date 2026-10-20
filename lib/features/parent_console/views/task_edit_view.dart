import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
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
  final List<int> _selectedDays = []; // 自定义日期的星期几
  bool _isMathTask = false; // 是否为每日数学题学习任务 (独立于周期类型)

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
      _selectedDays.addAll(widget.taskToEdit!.selectedDays);
      _isMathTask = widget.taskToEdit!.isMathTask;
      _mathRange = widget.taskToEdit!.mathRange;
      _mathOp = widget.taskToEdit!.mathOp;
      _mathCount = widget.taskToEdit!.mathCount;
      _mathPassPercent = widget.taskToEdit!.mathPassPercent;
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

      final task = Task(
        id: widget.taskToEdit?.id ?? const Uuid().v4(),
        title: _titleController.text,
        iconName: 'default_monster',
        rewardCoins: int.parse(_coinsController.text),
        rewardExp: int.parse(_expController.text),
        type: finalType,
        requirePhoto: _requirePhoto,
        selectedDays: _selectedType == 'custom_days' ? _selectedDays : const [],
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
                    decoration: InputDecoration(
                      labelText: '任务周期',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('每天任务 (每日巡逻)')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周任务 (每周特训)')),
                      DropdownMenuItem(value: 'checkin_week', child: Text('打卡一周 (连续打卡满一周)')),
                      DropdownMenuItem(value: 'custom_days', child: Text('打卡每天选择的日期')),
                      DropdownMenuItem(value: 'once', child: Text('单次任务 (紧急委托)')),
                    ],
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
