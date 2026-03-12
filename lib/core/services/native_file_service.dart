import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:file_picker/file_picker.dart';
import 'file_service.dart';

class NativeFileService implements FileService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PickedFile?> pickImage({bool fromCamera = false}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return PickedFile(
      bytes: bytes,
      name: image.name,
      extension: image.name.split('.').last,
    );
  }

  @override
  Future<PickedFile?> pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true, // Crucial for Web
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.bytes == null) return null;

    return PickedFile(
      bytes: file.bytes!,
      name: file.name,
      extension: file.extension,
    );
  }
}
