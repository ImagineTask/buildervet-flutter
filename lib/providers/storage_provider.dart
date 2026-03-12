import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/storage_service.dart';
import '../core/services/firebase_storage_service.dart';
import '../core/services/file_service.dart';
import '../core/services/native_file_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return FirebaseStorageService();
});

final fileServiceProvider = Provider<FileService>((ref) {
  return NativeFileService();
});
