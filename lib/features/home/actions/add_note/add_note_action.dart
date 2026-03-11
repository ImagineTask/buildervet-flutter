import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class AddNoteAction extends BaseActionTile {
  const AddNoteAction({super.key, required super.project});

  @override
  IconData get icon => Icons.sticky_note_2_outlined;

  @override
  String get label => 'Add\nNote';

  @override
  Color get color => const Color(0xFFFFB347);

  @override
  void onTap(BuildContext context) {
    // TODO: Open add note bottom sheet
  }
}
