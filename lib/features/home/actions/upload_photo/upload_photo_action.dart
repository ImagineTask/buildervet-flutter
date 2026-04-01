import 'package:flutter/material.dart';
import '../base_action_tile.dart';
import 'photo_management_page.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoManagementPage(project: project),
      ),
    );
  }
}