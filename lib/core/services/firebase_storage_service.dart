import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'storage_service.dart';

class FirebaseStorageService implements StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String> uploadFile({
    required Uint8List bytes,
    required String path,
    String? contentType,
  }) async {
    try {
      print('FirebaseStorage: Starting upload to $path (${bytes.length} bytes)');
      final ref = _storage.ref().child(path);

      // Adding metadata helps with mime types and browser behavior
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
      );

      final uploadTask = ref.putData(bytes, metadata);
      
      // Monitor progress for debugging
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('FirebaseStorage: Progress ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      }, onError: (e) {
        print('FirebaseStorage: Task stream error: $e');
      });

      final snapshot = await uploadTask;
      print('FirebaseStorage: Upload complete, getting URL...');
      final url = await snapshot.ref.getDownloadURL();
      print('FirebaseStorage: Got URL: $url');
      return url;
    } catch (e) {
      print('FirebaseStorage: Error in uploadFile: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e) {
      print('FirebaseStorage: Error in deleteFile: $e');
      rethrow;
    }
  }
}
