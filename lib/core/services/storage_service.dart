import 'dart:typed_data';

abstract class StorageService {
  /// Uploads a file to storage and returns the download URL.
  /// 
  /// [path] should be the full path in storage (e.g., 'avatars/user123.jpg' 
  /// or 'chat_images/image123.jpg').
  Future<String> uploadFile({
    required Uint8List bytes,
    required String path,
    String? contentType,
  });

  /// Deletes a file from storage.
  Future<void> deleteFile(String path);
}
