import 'dart:typed_data';

abstract class FileService {
  /// Picks an image from the device.
  /// 
  /// Returns a [PickedFile] containing the bytes and suggested filename, 
  /// or null if the user cancelled.
  Future<PickedFile?> pickImage({bool fromCamera = false});

  /// Picks any file from the device.
  Future<PickedFile?> pickFile();
}

class PickedFile {
  final Uint8List bytes;
  final String name;
  final String? extension;

  PickedFile({
    required this.bytes,
    required this.name,
    this.extension,
  });
}
