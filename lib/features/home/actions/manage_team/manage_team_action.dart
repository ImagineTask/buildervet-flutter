import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class ManageTeamAction extends BaseActionTile {
  const ManageTeamAction({super.key, required super.project});

  @override
  IconData get icon => Icons.group_outlined;

  @override
  String get label => 'Manage\nTeam';

  @override
  Color get color => const Color(0xFFFFB347);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to team management screen
  }
}
