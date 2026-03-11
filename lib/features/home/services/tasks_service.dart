import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

class TasksService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth-aware stream wrapper ─────────────────────────────────────────────
  // Wraps any Firestore stream so it:
  //   • Emits [] immediately when the user signs out
  //   • Cancels the Firestore listener to avoid permission-denied errors
  //   • Restarts the Firestore listener when the user signs back in

  Stream<List<TaskModel>> _authGuarded(
    Stream<List<TaskModel>> Function(String uid) builder,
  ) {
    late StreamController<List<TaskModel>> controller;
    StreamSubscription? authSub;
    StreamSubscription? firestoreSub;

    controller = StreamController<List<TaskModel>>.broadcast(
      onListen: () {
        authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
          // Cancel any existing Firestore listener first
          firestoreSub?.cancel();
          firestoreSub = null;

          if (user == null) {
            // Signed out — emit empty and stop
            controller.add([]);
          } else {
            // Signed in — start listening to Firestore
            firestoreSub = builder(user.uid).listen(
              controller.add,
              onError: controller.addError,
            );
          }
        });
      },
      onCancel: () {
        firestoreSub?.cancel();
        authSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ── Public streams ────────────────────────────────────────────────────────

  /// Projects owned by or shared with the current user.
  Stream<List<TaskModel>> streamProjects() {
    return _authGuarded((uid) {
      final ownerStream = _db
          .collection('tasks')
          .where('taskType', isEqualTo: 'project')
          .where('ownerId', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

      final participantStream = _db
          .collection('tasks')
          .where('taskType', isEqualTo: 'project')
          .where('participantIds', arrayContains: uid)
          .snapshots()
          .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

      return _mergeAndSort(ownerStream, participantStream);
    });
  }

  /// Child tasks belonging to a specific project.
  Stream<List<TaskModel>> streamTasksForProject(String projectTaskId) {
    return _authGuarded((_) {
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
    });
  }

  /// All tasks for the Tasks tab — scoped to current user.
  Stream<List<TaskModel>> streamAllTasks() {
    return _authGuarded((uid) {
      return _db
          .collection('tasks')
          .where('taskType', isEqualTo: 'task')
          .where('participantIds', arrayContains: uid)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(TaskModel.fromFirestore).toList();
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        return list;
      });
    });
  }

  /// Update a task's status field.
  Future<void> updateStatus(String docId, String newStatus) async {
    await _db.collection('tasks').doc(docId).update({'status': newStatus});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Merges two project streams, deduplicates by taskId, sorts by startTime.
  Stream<List<TaskModel>> _mergeAndSort(
    Stream<List<TaskModel>> streamA,
    Stream<List<TaskModel>> streamB,
  ) {
    List<TaskModel> a = [];
    List<TaskModel> b = [];
    late StreamController<List<TaskModel>> controller;

    controller = StreamController<List<TaskModel>>.broadcast(
      onListen: () {
        streamA.listen(
          (data) {
            a = data;
            controller.add(_dedupeSorted(a, b));
          },
          onError: controller.addError,
        );
        streamB.listen(
          (data) {
            b = data;
            controller.add(_dedupeSorted(a, b));
          },
          onError: controller.addError,
        );
      },
    );

    return controller.stream;
  }

  List<TaskModel> _dedupeSorted(List<TaskModel> a, List<TaskModel> b) {
    final seen = <String>{};
    final merged = <TaskModel>[];
    for (final t in [...a, ...b]) {
      if (seen.add(t.taskId)) merged.add(t);
    }
    merged.sort((x, y) => x.startTime.compareTo(y.startTime));
    return merged;
  }
}