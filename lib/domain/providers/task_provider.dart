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
    // 无任务时保持为空，交由家长在引导界面 / 控制台自行添加，
    // 不再注入模拟测试数据 (避免「什么都不选却出现默认任务」)。
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
