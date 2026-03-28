import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../base_action_tile.dart';

class DenyTaskAction extends BaseActionTile {
  const DenyTaskAction({super.key, required super.project});

  @override
  bool get isDisabled =>
      project.isActive ||
      project.isDenied ||
      project.isDone ||
      project.isRevising;

  @override
  String get disabledReason {
    if (project.isActive) return 'Cannot deny an accepted task';
    if (project.isDenied) return 'Task already denied';
    if (project.isDone) return 'Task is completed';
    if (project.isRevising) return 'Task is under revision';
    return '';
  }

  @override
  IconData get icon => Icons.cancel_outlined;

  @override
  String get label => 'Deny\nTask';

  @override
  Color get color => const Color(0xFFFF6B6B);

  @override
  void onTap(BuildContext context) async {
    if (isDisabled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Deny Task',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        content: Text(
          'Are you sure you want to deny "${project.taskName}"? This will notify the project owner.',
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
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Keep a reference to navigator before async gap
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskRef = firestore.collection('tasks').doc(project.id);
      final now = DateTime.now().toUtc().toIso8601String();
      final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';

      final batch = firestore.batch();

      batch.update(taskRef, {
        'status': 'unassigned',
        'updatedAt': now,
        'actionSpace': [],
        'assignedBuilderIds': [],
        'participantIds': [project.ownerId],
        'metadata.deniedAt': now,
        'metadata.deniedBy': currentUser?.uid,
      });

      final eventRef = taskRef.collection('events').doc(eventId);
      batch.set(eventRef, {
        'id': eventId,
        'type': 'task_denied',
        'timestamp': now,
        'actorId': currentUser?.uid ?? project.ownerId,
        'actorName': currentUser?.displayName ?? 'Unknown',
        'actorRole': 'builder',
        'data': {
          'previousStatus': project.status,
          'newStatus': 'unassigned',
          'deniedBy': currentUser?.uid,
        },
      });

      await batch.commit();

      navigator.pop(); // dismiss loader

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Task denied. Project owner has been notified.'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
    } catch (e) {
      navigator.pop(); // dismiss loader

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to deny task: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}