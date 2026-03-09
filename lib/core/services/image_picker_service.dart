import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndEditImage(BuildContext context) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final Uint8List bytes = await image.readAsBytes();
    final Uint8List? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          bytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List editedBytes) async {
              Navigator.pop(context, editedBytes);
            },
          ),
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.material,
          ),
        ),
      ),
    );

    if (result != null) {
      if (kIsWeb) {
        return 'data:image/jpeg;base64,${base64Encode(result)}';
      }
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(result);
      return path;
    }

    return null;
  }
}
