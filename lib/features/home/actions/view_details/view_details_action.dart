import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class ViewDetailsAction extends BaseActionTile {
  const ViewDetailsAction({super.key, required super.project});

  @override
  IconData get icon => Icons.info_outline;

  @override
  String get label => 'View\nDetails';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to project detail screen
  }
}
