import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../base_action_tile.dart';

class NegotiateTaskAction extends BaseActionTile {
  const NegotiateTaskAction({super.key, required super.project});

  @override
  IconData get icon => Icons.handshake_outlined;

  @override
  String get label => 'Negotiate\nTask';

  @override
  Color get color => const Color(0xFF4ECDC4);

  @override
  void onTap(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(project.id)
        .update({
      'status': 'negotiating',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Negotiation request sent'),
          backgroundColor: Color(0xFF4ECDC4),
        ),
      );
    }
  }
}