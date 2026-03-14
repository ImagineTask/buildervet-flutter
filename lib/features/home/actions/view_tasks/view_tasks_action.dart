import 'package:flutter/material.dart';
import '../base_action_tile.dart';

class ViewTasksAction extends BaseActionTile {
  const ViewTasksAction({super.key, required super.project});

  @override
  IconData get icon => Icons.task_alt_outlined;

  @override
  String get label => 'View\nTasks';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to task list for this project
  }
}
