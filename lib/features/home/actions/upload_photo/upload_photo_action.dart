import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class UploadPhotoAction extends BaseActionTile {
  const UploadPhotoAction({super.key, required super.project});

  @override
  IconData get icon => Icons.add_a_photo_outlined;

  @override
  String get label => 'Upload\nPhoto';

  @override
  Color get color => const Color(0xFFFF6B6B);

  @override
  void onTap(BuildContext context) {
    // TODO: Open image picker and upload to storage
  }
}
