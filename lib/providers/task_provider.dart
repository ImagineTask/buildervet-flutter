import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../core/di/service_locator.dart';

/// All tasks
final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getAllTasks();
});

/// Projects only
final projectsProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getProjects();
});

/// Tasks for a specific project
final projectTasksProvider =
    FutureProvider.family<List<Task>, String>((ref, projectId) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTasksByProject(projectId);
});

/// Standalone tasks (no parent project)
final standaloneTasksProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getStandaloneTasks();
});

/// Single task by ID
final taskByIdProvider =
    FutureProvider.family<Task?, String>((ref, taskId) async {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getTaskById(taskId);
});

/// Search
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Task>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final repo = ref.watch(taskRepositoryProvider);
  return repo.searchTasks(query);
});
