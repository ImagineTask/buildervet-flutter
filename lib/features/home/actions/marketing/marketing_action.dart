import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';
import 'marketing_page.dart';

class MarketingAction extends BaseActionTile {
  const MarketingAction({super.key, required super.project});

  @override
  IconData get icon => Icons.campaign_outlined;

  @override
  String get label => 'Marketing';

  @override
  Color get color => const Color(0xFFE056A0);

  @override
  void onTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingPage(project: project),
      ),
    );
  }
}
