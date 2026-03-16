import 'package:flutter/material.dart';
import '../base_action_tile.dart';
import 'view_tasks_page.dart';

class ViewTasksAction extends BaseActionTile {
  const ViewTasksAction({super.key, required super.project});

  @override
  IconData get icon => Icons.task_alt_outlined;

  @override
  String get label => 'Tasks';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewTasksPage(project: project),
      ),
    );
  }
}
