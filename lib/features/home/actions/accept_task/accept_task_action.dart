import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../base_action_tile.dart';

class AcceptTaskAction extends BaseActionTile {
  const AcceptTaskAction({super.key, required super.project});

  @override
  IconData get icon => Icons.check_circle_outline;

  @override
  String get label => 'Accept\nTask';

  @override
  Color get color => const Color(0xFF43C59E);

  @override
  void onTap(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Task',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: Text(
          'Are you sure you want to accept "${project.taskName}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF43C59E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(project.id)
          .update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task accepted!'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    }
  }
}