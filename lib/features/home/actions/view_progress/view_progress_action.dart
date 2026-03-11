import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class ViewProgressAction extends BaseActionTile {
  const ViewProgressAction({super.key, required super.project});

  @override
  IconData get icon => Icons.insights_outlined;

  @override
  String get label => 'View\nProgress';

  @override
  Color get color => const Color(0xFF43C59E);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to progress screen
  }
}
