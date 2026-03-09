import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    try {
      print('FirebaseStorage: Starting upload for $fileName (${bytes.length} bytes)');
      final ref = _storage.ref().child('chat_images/$fileName');
      
      // Adding metadata helps with mime types and browser behavior
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': fileName},
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
      print('FirebaseStorage: Error in uploadImage: $e');
      rethrow;
    }
  }

  Future<String> uploadFile(File file, String fileName) async {
    try {
      print('FirebaseStorage: Starting file upload for $fileName');
      final ref = _storage.ref().child('chat_files/$fileName');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('FirebaseStorage: Error in uploadFile: $e');
      rethrow;
    }
  }
}
