import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'storage_service.dart';
import 'logger_service.dart';

class FirebaseStorageService implements StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String> uploadFile({
    required Uint8List bytes,
    required String path,
    String? contentType,
  }) async {
    try {
      Log.i('FirebaseStorage: Starting upload to $path (${bytes.length} bytes)');
      final ref = _storage.ref().child(path);

      // Lookup mime type if not provided
      final String? detectedType = contentType ?? lookupMimeType(path, headerBytes: bytes);
      
      final metadata = SettableMetadata(
        contentType: detectedType ?? 'application/octet-stream',
      );

      final uploadTask = ref.putData(bytes, metadata);
      
      // Monitor progress for debugging
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        Log.d('FirebaseStorage: Progress ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      }, onError: (e) {
        Log.e('FirebaseStorage: Task stream error: $e', e);
      });

      final snapshot = await uploadTask;
      Log.i('FirebaseStorage: Upload complete, getting URL...');
      final url = await snapshot.ref.getDownloadURL();
      Log.i('FirebaseStorage: Got URL: $url');
      return url;
    } catch (e) {
      Log.e('FirebaseStorage: Error in uploadFile: $e', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e) {
      Log.e('FirebaseStorage: Error in deleteFile: $e', e);
      rethrow;
    }
  }
}
