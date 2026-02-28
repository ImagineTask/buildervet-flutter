import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/task.dart';
import '../repositories/task_repository.dart';

class MockTaskRepository implements TaskRepository {
  List<Task>? _cache;

  Future<List<Task>> _loadTasks() async {
    if (_cache != null) return _cache!;

    final jsonString = await rootBundle.loadString('assets/data/mock_tasks.json');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final tasksList = jsonData['tasks'] as List<dynamic>;

    _cache = tasksList
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();

    return _cache!;
  }

  @override
  Future<List<Task>> getAllTasks() async {
    return _loadTasks();
  }

  @override
  Future<List<Task>> getProjects() async {
    final tasks = await _loadTasks();
    return tasks.where((t) => t.isProject).toList();
  }

  @override
  Future<List<Task>> getTasksByProject(String projectId) async {
    final tasks = await _loadTasks();
    return tasks.where((t) => t.parentTaskId == projectId).toList();
  }

  @override
  Future<List<Task>> getStandaloneTasks() async {
    final tasks = await _loadTasks();
    return tasks.where((t) => !t.isProject && !t.hasParent).toList();
  }

  @override
  Future<Task?> getTaskById(String taskId) async {
    final tasks = await _loadTasks();
    try {
      return tasks.firstWhere((t) => t.taskId == taskId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createTask(Task task) async {
    final tasks = await _loadTasks();
    tasks.add(task);
  }

  @override
  Future<void> updateTask(Task task) async {
    final tasks = await _loadTasks();
    final index = tasks.indexWhere((t) => t.taskId == task.taskId);
    if (index != -1) {
      tasks[index] = task;
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final tasks = await _loadTasks();
    tasks.removeWhere((t) => t.taskId == taskId);
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final tasks = await _loadTasks();
    final lowerQuery = query.toLowerCase();
    return tasks.where((t) {
      return t.taskName.toLowerCase().contains(lowerQuery) ||
          t.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
