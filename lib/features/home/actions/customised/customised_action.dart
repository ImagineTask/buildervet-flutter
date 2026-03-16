import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';
import 'add_custom_tile_sheet.dart';
import 'custom_tile_service.dart';

class CustomisedAction extends BaseActionTile {
  const CustomisedAction({super.key, required super.project});

  @override
  IconData get icon => Icons.add_circle_outline_rounded;

  @override
  String get label => 'Customise';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCustomTileSheet(
        projectId: project.id,
        service: CustomTileService(),
      ),
    );
  }
}
