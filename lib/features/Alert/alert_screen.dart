import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/Home/models/task_model.dart';
import '../../features/Home/actions/view_tasks/view_tasks_page.dart';
import '../../features/Home/actions/review_quotes/quote_management_page.dart';
import '../../../main.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  Stream<List<_Alert>> _alertStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('alerts')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return _Alert(
                id: doc.id,
                title: d['title'] ?? '',
                description: d['description'] ?? '',
                time: _formatTime(d['createdAt']),
                type: _parseType(d['type']),
                isRead: d['isRead'] ?? false,
                taskId: d['taskId'],
                isQuoteAlert: _isQuoteAlert(
                  d['type'],
                  d['title'],
                  d['description'],
                ),
              );
            }).toList());
  }

  static bool _isQuoteAlert(
      String? type, String? title, String? description) {
    // Match by explicit type if backend ever sets it
    const quoteTypes = {
      'quote',
      'quote_submitted',
      'quote_approved',
      'quote_declined',
      'quote_updated',
    };
    if (quoteTypes.contains(type)) return true;

    // Fallback: match by title/description keywords
    final combined =
        '${title ?? ''} ${description ?? ''}'.toLowerCase();
    return combined.contains('quote');
  }

  static String _formatTime(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  static AlertType _parseType(String? type) {
    switch (type) {
      case 'warning':
        return AlertType.warning;
      case 'error':
        return AlertType.error;
      case 'success':
        return AlertType.success;
      case 'security':
        return AlertType.security;
      default:
        return AlertType.info;
    }
  }

  Future<void> _markAsRead(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection('alerts')
        .doc(uid)
        .collection('items')
        .doc(docId)
        .update({'isRead': true});
  }

  Future<void> _markAllRead(String uid, List<_Alert> alerts) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final alert in alerts.where((a) => !a.isRead)) {
      final ref = FirebaseFirestore.instance
          .collection('alerts')
          .doc(uid)
          .collection('items')
          .doc(alert.id);
      batch.update(ref, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _deleteAlert(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection('alerts')
        .doc(uid)
        .collection('items')
        .doc(docId)
        .delete();
  }

  Future<void> _deleteAll(
      BuildContext context, String uid, List<_Alert> alerts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
        content: const Text(
          'Are you sure you want to delete all notifications? This cannot be undone.',
          style: TextStyle(color: Colors.grey),
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final alert in alerts) {
      final ref = FirebaseFirestore.instance
          .collection('alerts')
          .doc(uid)
          .collection('items')
          .doc(alert.id);
      batch.delete(ref);
    }
    await batch.commit();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _handleTap(
      BuildContext context, String uid, _Alert alert) async {
    await _markAsRead(uid, alert.id);
    if (!context.mounted) return;

    final taskId = alert.taskId;
    if (taskId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loader

      if (!taskDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task no longer exists'),
            backgroundColor: Colors.grey,
          ),
        );
        return;
      }

      final task = TaskModel.fromFirestore(taskDoc);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // ── Quote alert → QuoteManagementPage (always checked first) ───
      if (alert.isQuoteAlert) {
        // taskId may point to the project directly or a child task
        TaskModel project = task;

        if (task.taskType == 'task' && task.parentTaskId != null) {
          final projectDoc = await FirebaseFirestore.instance
              .collection('tasks')
              .doc(task.parentTaskId)
              .get();

          if (!context.mounted) return;
          if (!projectDoc.exists) return;

          project = TaskModel.fromFirestore(projectDoc);
        }

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuoteManagementPage(
              projectId: project.taskId,
              projectName: project.taskName,
            ),
          ),
        );
        return;
      }

      // ── Builder: task assigned to them → Home Tasks tab ────────────
      if (task.taskType == 'task' &&
          task.assignedBuilderIds.contains(currentUid)) {
        if (!context.mounted) return;
        homeTabNotifier.value = 1;
        return;
      }

      // ── Project owner: fetch parent project → ViewTasksPage ────────
      if (task.taskType == 'task' && task.parentTaskId != null) {
        final projectDoc = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(task.parentTaskId)
            .get();

        if (!context.mounted) return;

        if (projectDoc.exists) {
          final project = TaskModel.fromFirestore(projectDoc);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewTasksPage(project: project),
            ),
          );
        }
      } else if (task.taskType == 'project') {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewTasksPage(project: task),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: StreamBuilder<List<_Alert>>(
          stream: _alertStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF6C63FF)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Something went wrong',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            }

            final alerts = snapshot.data ?? [];
            final unread = alerts.where((a) => !a.isRead).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alerts',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          if (unread > 0)
                            Text(
                              '$unread unread notifications',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                      if (alerts.isNotEmpty && uid != null)
                        Row(
                          children: [
                            if (unread > 0)
                              TextButton(
                                onPressed: () =>
                                    _markAllRead(uid, alerts),
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: () =>
                                  _deleteAll(context, uid, alerts),
                              icon: const Icon(
                                  Icons.delete_sweep_outlined),
                              color: const Color(0xFFFF6B6B),
                              tooltip: 'Clear all',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          itemCount: alerts.length,
                          itemBuilder: (context, index) {
                            final alert = alerts[index];
                            return Dismissible(
                              key: Key(alert.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                if (uid != null)
                                  _deleteAlert(uid, alert.id);
                              },
                              background: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                padding:
                                    const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B6B),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                alignment: Alignment.centerRight,
                                child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 24),
                              ),
                              child: _AlertCard(
                                alert: alert,
                                onTap: uid != null
                                    ? () => _handleTap(
                                        context, uid, alert)
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

enum AlertType { warning, error, success, info, security }

class _Alert {
  final String id;
  final String title;
  final String description;
  final String time;
  final AlertType type;
  final bool isRead;
  final String? taskId;
  final bool isQuoteAlert;

  const _Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    required this.isRead,
    this.taskId,
    this.isQuoteAlert = false,
  });
}

// ── Extensions ────────────────────────────────────────────────────────────────

extension _AlertTypeExtension on AlertType {
  Color get color {
    switch (this) {
      case AlertType.warning:
        return const Color(0xFFFFB347);
      case AlertType.error:
        return const Color(0xFFFF6B6B);
      case AlertType.success:
        return const Color(0xFF43C59E);
      case AlertType.info:
        return const Color(0xFF6C63FF);
      case AlertType.security:
        return const Color(0xFFE056A0);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.warning:
        return Icons.warning_amber_outlined;
      case AlertType.error:
        return Icons.error_outline;
      case AlertType.success:
        return Icons.check_circle_outline;
      case AlertType.info:
        return Icons.info_outline;
      case AlertType.security:
        return Icons.security_outlined;
    }
  }

  String get label {
    switch (this) {
      case AlertType.warning:
        return 'Warning';
      case AlertType.error:
        return 'Error';
      case AlertType.success:
        return 'Success';
      case AlertType.info:
        return 'Info';
      case AlertType.security:
        return 'Security';
    }
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final _Alert alert;
  final VoidCallback? onTap;

  const _AlertCard({required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = alert.type.color;
    final hasNavigation = alert.taskId != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: alert.isRead
              ? null
              : Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(alert.type.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontWeight: alert.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alert.type.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert.time,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                      const Spacer(),
                      if (hasNavigation)
                        Row(
                          children: [
                            Text(
                              alert.isQuoteAlert
                                  ? 'View quote'
                                  : 'View task',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right,
                                size: 14, color: color),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}