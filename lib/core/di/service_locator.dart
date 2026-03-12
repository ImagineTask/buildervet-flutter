import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../data/repositories/task_repository.dart';
import '../../data/remote/firestore_task_repository.dart';
import '../../data/remote/firestore_chat_repository.dart';
import '../../providers/storage_provider.dart';
import '../services/storage_service.dart';
import '../services/file_service.dart';

/// Task repository — reads/writes directly to Firestore
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirestoreTaskRepository();
});

final chatRepositoryProvider = Provider<FirestoreChatRepository>((ref) {
  return FirestoreChatRepository();
});

final storageLocatorProvider = Provider<StorageService>((ref) {
  return ref.watch(storageServiceProvider);
});

final fileLocatorProvider = Provider<FileService>((ref) {
  return ref.watch(fileServiceProvider);
});

final httpProvider = Provider((ref) => http.Client());