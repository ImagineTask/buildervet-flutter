import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../base_action_tile.dart';

class CreateInvoiceAction extends BaseActionTile {
  const CreateInvoiceAction({super.key, required super.project});

  @override
  IconData get icon => Icons.receipt_long_outlined;

  @override
  String get label => 'Create\nInvoice';

  @override
  Color get color => const Color(0xFF6C63FF);

  @override
  void onTap(BuildContext context) {
    // TODO: Navigate to invoice creation screen
  }
}
