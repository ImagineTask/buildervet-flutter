import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../core/di/service_locator.dart';
import '../data/remote/firestore_task_repository.dart';

/// All tasks for current user
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

/// Single task by ID (with events loaded)
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

/// Delete a task and refresh providers
final deleteTaskProvider = Provider((ref) {
  return (String taskId) async {
    final repo = ref.read(taskRepositoryProvider) as FirestoreTaskRepository;
    await repo.deleteTask(taskId);
    ref.invalidate(allTasksProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(standaloneTasksProvider);
  };
});

/// Archive a task and refresh providers
final archiveTaskProvider = Provider((ref) {
  return (String taskId) async {
    final repo = ref.read(taskRepositoryProvider) as FirestoreTaskRepository;
    await repo.archiveTask(taskId);
    ref.invalidate(allTasksProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(standaloneTasksProvider);
  };
});