import '../../models/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Future<List<Task>> getProjects();
  Future<List<Task>> getTasksByProject(String projectId);
  Future<List<Task>> getStandaloneTasks();
  Future<Task?> getTaskById(String taskId);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<List<Task>> searchTasks(String query);
}
