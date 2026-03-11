import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload images');
      }

      print('FirebaseStorage: Starting upload for $fileName (${bytes.length} bytes) by user ${user.uid}');
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
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload files');
      }
      print('FirebaseStorage: Starting file upload for $fileName by user ${user.uid}');
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
