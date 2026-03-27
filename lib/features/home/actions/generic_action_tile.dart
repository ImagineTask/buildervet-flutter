import 'package:flutter/material.dart';
import 'base_action_tile.dart';

class GenericAction extends BaseActionTile {
  final String actionName;

  const GenericAction({super.key, required super.project, required this.actionName});

  @override
  IconData get icon => Icons.touch_app_outlined;

  @override
  String get label => actionName.replaceAll('_', ' ').toUpperCase();

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action "$label" triggered for ${project.taskName}')),
    );
  }
}
