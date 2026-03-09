import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../data/repositories/task_repository.dart';
import '../../data/remote/firestore_task_repository.dart';
import '../../data/remote/firestore_chat_repository.dart';
import '../services/firebase_storage_service.dart';

/// Task repository — reads/writes directly to Firestore
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirestoreTaskRepository();
});

final chatRepositoryProvider = Provider<FirestoreChatRepository>((ref) {
  return FirestoreChatRepository();
});

final storageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});

final httpProvider = Provider((ref) => http.Client());