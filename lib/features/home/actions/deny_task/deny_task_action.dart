import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../base_action_tile.dart';

class DenyTaskAction extends BaseActionTile {
  const DenyTaskAction({super.key, required super.project});

  @override
  IconData get icon => Icons.cancel_outlined;

  @override
  String get label => 'Deny\nTask';

  @override
  Color get color => const Color(0xFFFF6B6B);

  @override
  void onTap(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deny Task',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: Text(
          'Are you sure you want to deny "${project.taskName}"? This will notify the project owner.',
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
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(project.id)
          .update({
        'status': 'denied',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task denied.'),
            backgroundColor: Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }
}