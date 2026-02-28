import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/mock/mock_task_repository.dart';
// import '../../data/remote/api_task_repository.dart';

/// Central place to swap mock <-> real implementations.
/// When backend is ready, just change the providers here.

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  if (AppConfig.useMockData) {
    return MockTaskRepository();
  } else {
    // return ApiTaskRepository(ref.read(apiClientProvider));
    return MockTaskRepository(); // fallback until backend is ready
  }
});
