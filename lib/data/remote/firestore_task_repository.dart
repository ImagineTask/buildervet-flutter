import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task.dart';
import '../../models/task_event.dart';
import '../repositories/task_repository.dart';

class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Fetch all tasks owned by the current user (single query, filter locally)
  Future<List<Task>> _fetchUserTasks() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final snapshot = await _db
        .collection('tasks')
        .where('ownerId', isEqualTo: uid)
        .get();

    return snapshot.docs
        .map((doc) => Task.fromJson(doc.data()))
        .where((t) => t.status.name != 'archived')
        .toList();
  }

  @override
  Future<List<Task>> getAllTasks() async {
    return _fetchUserTasks();
  }

  @override
  Future<List<Task>> getProjects() async {
    final tasks = await _fetchUserTasks();
    return tasks.where((t) => t.isProject).toList();
  }

  @override
  Future<List<Task>> getTasksByProject(String projectId) async {
    final snapshot = await _db
        .collection('tasks')
        .where('parentTaskId', isEqualTo: projectId)
        .get();

    final tasks = snapshot.docs.map((doc) => Task.fromJson(doc.data())).toList();
    tasks.sort((a, b) {
      final orderA = a.metadata['taskOrder'] as int? ?? 0;
      final orderB = b.metadata['taskOrder'] as int? ?? 0;
      return orderA.compareTo(orderB);
    });
    return tasks;
  }

  @override
  Future<List<Task>> getStandaloneTasks() async {
    final tasks = await _fetchUserTasks();
    return tasks.where((t) => !t.isProject && t.parentTaskId == null).toList();
  }

  @override
  Future<Task?> getTaskById(String taskId) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (!doc.exists) return null;

    final task = Task.fromJson(doc.data()!);

    try {
      final eventsSnapshot = await _db
          .collection('tasks')
          .doc(taskId)
          .collection('events')
          .get();

      final events = eventsSnapshot.docs
          .map((e) => TaskEvent.fromJson(e.data()))
          .toList();
      events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return task.copyWith(events: events);
    } catch (_) {
      return task;
    }
  }

  @override
  Future<void> createTask(Task task) async {
    await _db.collection('tasks').doc(task.taskId).set(task.toJson());
  }

  @override
  Future<void> updateTask(Task task) async {
    await _db.collection('tasks').doc(task.taskId).update(task.toJson());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (!doc.exists) return;

    final taskData = doc.data()!;
    final isProject = taskData['taskType'] == 'project';

    if (isProject) {
      final children = await _db
          .collection('tasks')
          .where('parentTaskId', isEqualTo: taskId)
          .get();

      final batch = _db.batch();
      for (final child in children.docs) {
        batch.delete(child.reference);
      }
      batch.delete(_db.collection('tasks').doc(taskId));
      await batch.commit();
    } else {
      await _db.collection('tasks').doc(taskId).delete();
    }
  }

  Future<void> archiveTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'archived',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final allTasks = await _fetchUserTasks();
    final lowerQuery = query.toLowerCase();
    return allTasks.where((t) {
      return t.taskName.toLowerCase().contains(lowerQuery) ||
          t.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}