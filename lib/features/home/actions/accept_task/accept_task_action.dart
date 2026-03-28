import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../base_action_tile.dart';

class AcceptTaskAction extends BaseActionTile {
  const AcceptTaskAction({super.key, required super.project});

  @override
  bool get isDisabled =>
      project.status == 'active' ||
      project.status == 'denied' ||
      project.status == 'done' ||
      project.status == 'revising';

  @override
  String get disabledReason {
    if (project.status == 'active') return 'Task already accepted';
    if (project.status == 'denied') return 'Task has been denied';
    if (project.status == 'done') return 'Task is completed';
    if (project.status == 'revising') return 'Task is under revision';
    return '';
  }

  @override
  IconData get icon => Icons.check_circle_outline;

  @override
  String get label => 'Accept\nTask';

  @override
  Color get color => const Color(0xFF43C59E);

  @override
  void onTap(BuildContext context) async {
    if (isDisabled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Accept Task',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        content: Text(
          'Are you sure you want to accept "${project.taskName}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF43C59E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskRef = firestore.collection('tasks').doc(project.id);
      final now = DateTime.now().toUtc().toIso8601String();
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = firestore.batch();

      batch.update(taskRef, {
        'status': 'active',
        'updatedAt': now,
        'actionSpace': ['accept_task', 'deny_task', 'revise_task', 'photo_task', 'invoice_task', 'add_note'],
      });

      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'task_accepted',
        'timestamp': now,
        'actorId': project.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'homeowner',
        'data': {
          'previousStatus': project.status,
          'newStatus': 'active',
        },
      });

      await batch.commit();

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task accepted!'),
            backgroundColor: Color(0xFF43C59E),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}