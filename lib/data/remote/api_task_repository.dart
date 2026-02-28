import '../../models/task.dart';
import '../repositories/task_repository.dart';

/// TODO: Implement when backend is ready.
/// Replace MockTaskRepository with this in service_locator.dart
class ApiTaskRepository implements TaskRepository {
  // final ApiClient _client;
  // ApiTaskRepository(this._client);

  @override
  Future<List<Task>> getAllTasks() async {
    // TODO: GET /api/tasks
    throw UnimplementedError('Connect to real backend');
  }

  @override
  Future<List<Task>> getProjects() async {
    // TODO: GET /api/tasks?type=project
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> getTasksByProject(String projectId) async {
    // TODO: GET /api/tasks?parentTaskId=$projectId
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> getStandaloneTasks() async {
    throw UnimplementedError();
  }

  @override
  Future<Task?> getTaskById(String taskId) async {
    // TODO: GET /api/tasks/$taskId
    throw UnimplementedError();
  }

  @override
  Future<void> createTask(Task task) async {
    // TODO: POST /api/tasks
    throw UnimplementedError();
  }

  @override
  Future<void> updateTask(Task task) async {
    // TODO: PUT /api/tasks/${task.taskId}
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    // TODO: DELETE /api/tasks/$taskId
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    // TODO: GET /api/tasks/search?q=$query
    throw UnimplementedError();
  }
}
