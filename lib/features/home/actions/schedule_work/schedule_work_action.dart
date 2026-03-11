import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class ScheduleWorkAction extends BaseActionTile {
  const ScheduleWorkAction({super.key, required super.project});

  @override
  IconData get icon => Icons.calendar_month_outlined;

  @override
  String get label => 'Schedule\nWork';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    // TODO: Open scheduler / calendar
  }
}
