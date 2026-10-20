
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/task.dart';
import 'family_provider.dart';

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  final storage = ref.watch(storageProvider);
  return TaskNotifier(storage)..loadTasks();
});

class TaskNotifier extends StateNotifier<List<Task>> {
  final _storage;

  TaskNotifier(this._storage) : super([]);

  void loadTasks() {
    state = _storage.getTasks();
    // 模拟测试数据
    if (state.isEmpty) {
      state = [
        Task(id: '1', title: '消灭蛀牙怪兽 (认真刷牙)', iconName: 'tooth_monster', rewardCoins: 10, rewardExp: 50, type: 'daily'),
        Task(id: '2', title: '整理防卫基地 (收拾房间)', iconName: 'mess_monster', rewardCoins: 20, rewardExp: 100, type: 'daily'),
      ];
      _storage.saveTasks(state);
    }
  }

  void addTask(Task task) {
    state = [...state, task];
    _storage.saveTasks(state);
  }

  // 删除任务
  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
    _storage.saveTasks(state);
  }

  // 更新任务
  void updateTask(Task updatedTask) {
    state = state.map((task) {
      if (task.id == updatedTask.id) {
        return updatedTask;
      }
      return task;
    }).toList();
    _storage.saveTasks(state);
  }
}