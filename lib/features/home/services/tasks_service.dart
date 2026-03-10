import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TasksService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── All documents live in one flat "tasks" collection ──

  /// Stream all project-type tasks (taskType == "project")
  Stream<List<TaskModel>> streamProjects() {
    return _db
        .collection('tasks')
        .where('taskType', isEqualTo: 'project')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(TaskModel.fromFirestore).toList();
          list.sort((a, b) => a.startTime.compareTo(b.startTime));
          return list;
        });
  }

  /// Stream all child tasks that belong to a specific project
  Stream<List<TaskModel>> streamTasksForProject(String projectTaskId) {
    return _db
        .collection('tasks')
        .where('parentTaskId', isEqualTo: projectTaskId)
        .where('taskType', isEqualTo: 'task')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(TaskModel.fromFirestore).toList();
          list.sort((a, b) {
            final aOrder = (a.metadata['taskOrder'] ?? 99) as int;
            final bOrder = (b.metadata['taskOrder'] ?? 99) as int;
            return aOrder.compareTo(bOrder);
          });
          return list;
        });
  }

  /// Stream ALL non-project tasks for the Tasks tab
  Stream<List<TaskModel>> streamAllTasks() {
    return _db
        .collection('tasks')
        .where('taskType', isEqualTo: 'task')
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(TaskModel.fromFirestore).toList();
          list.sort((a, b) => a.startTime.compareTo(b.startTime));
          return list;
        });
  }

  /// Update a task's status field
  Future<void> updateStatus(String docId, String newStatus) async {
    await _db.collection('tasks').doc(docId).update({'status': newStatus});
  }
}